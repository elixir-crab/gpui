defmodule GPUI.Template.Parser do
  @moduledoc false

  # Parses the HEEx subset accepted by `GPUI.Template` into a node tree:
  #
  #   {:tag, name, attrs, children, meta}
  #   {:component, :remote | :local, name, attrs, children, meta}
  #   {:slot, name, attrs, children, meta}
  #   {:text, binary}
  #   {:expr, code, meta}
  #
  # Attributes are `{name, {:string, value} | {:expr, code, meta}, meta}`.
  # Whitespace-only text and HTML comments are dropped. Expressions end at the
  # first unbalanced `}`; like HEEx, braces inside Elixir strings count unless
  # escaped as `\{` or `\}`.

  @space_chars ~c"\s\t\f"
  @name_stop_chars ~c">/=\r\n\"'" ++ @space_chars

  @spec parse!(String.t(), keyword()) :: list()
  def parse!(source, opts) do
    state = %{file: Keyword.fetch!(opts, :file)}
    {nodes, "", _pos} = children(source, {Keyword.get(opts, :line, 1), 1}, nil, state, [], [])
    nodes
  end

  # Children are parsed until the parent's closing tag (or the end of input at
  # the root). `text` collects the current text run in reverse.
  defp children("</" <> rest, pos, parent, state, text, acc) do
    acc = flush_text(text, acc)
    {name, rest, name_end} = name!(rest, advance(pos, 2), state, "expected tag name after </")

    rest =
      case rest do
        ">" <> rest -> rest
        _rest -> syntax_error!(state, name_end, "expected closing `>`")
      end

    case parent do
      %{name: ^name} ->
        {Enum.reverse(acc), rest, advance(name_end, 1)}

      %{name: open, meta: meta} ->
        syntax_error!(
          state,
          pos,
          "unmatched closing tag. Expected </#{open}> for <#{open}> at line #{meta.line}, got: </#{name}>"
        )

      nil ->
        syntax_error!(state, pos, "missing opening tag for </#{name}>")
    end
  end

  defp children("<%" <> _rest, pos, _parent, state, _text, _acc) do
    syntax_error!(state, pos, "EEx tags are not supported in GPUI templates; use {expression}")
  end

  defp children("<!--" <> rest, pos, parent, state, text, acc) do
    {rest, pos} = skip_comment(rest, advance(pos, 4), pos, state)
    children(rest, pos, parent, state, text, acc)
  end

  defp children("<" <> rest, pos, parent, state, text, acc) do
    {node, rest, pos} = element(rest, pos, parent, state)
    children(rest, pos, parent, state, [], [node | flush_text(text, acc)])
  end

  defp children("{" <> rest, pos, parent, state, text, acc) do
    expr_pos = advance(pos, 1)
    {code, rest, pos} = expression!(rest, expr_pos, pos, state)
    node = {:expr, code, meta(expr_pos)}
    children(rest, pos, parent, state, [], [node | flush_text(text, acc)])
  end

  defp children("", _pos, nil, _state, text, acc) do
    {Enum.reverse(flush_text(text, acc)), "", nil}
  end

  defp children("", _pos, %{name: name, meta: meta}, state, _text, _acc) do
    syntax_error!(
      state,
      {meta.line, meta.column},
      "end of template reached without closing tag for <#{name}>"
    )
  end

  defp children(rest, pos, parent, state, text, acc) do
    {char, rest, pos} = next_char(rest, pos)
    children(rest, pos, parent, state, [char | text], acc)
  end

  defp element(rest, open_pos, parent, state) do
    {name, rest, pos} =
      name!(
        rest,
        advance(open_pos, 1),
        state,
        "expected tag name after <. If you meant to use < as part of a text, use &lt; instead"
      )

    meta = meta(open_pos)
    kind = classify!(name, open_pos, parent, state)
    {attrs, closing, rest, pos} = attributes(rest, pos, state, [])

    {children, rest, pos} =
      case closing do
        :self -> {[], rest, pos}
        :open -> children(rest, pos, %{name: name, kind: kind, meta: meta}, state, [], [])
      end

    node =
      case kind do
        {:tag, tag} -> {:tag, tag, attrs, children, meta}
        {:slot, slot} -> {:slot, slot, attrs, children, meta}
        {component, name} -> {:component, component, name, attrs, children, meta}
      end

    {node, rest, pos}
  end

  defp classify!(":" <> slot, pos, parent, state) do
    cond do
      slot == "inner_block" ->
        syntax_error!(state, pos, "the slot name :inner_block is reserved")

      not match?(%{kind: {kind, _name}} when kind in [:remote, :local], parent) ->
        syntax_error!(
          state,
          pos,
          "invalid slot entry <:#{slot}>. A slot entry must be a direct child of a component"
        )

      true ->
        {:slot, slot}
    end
  end

  defp classify!(".", pos, _parent, state),
    do: syntax_error!(state, pos, "a component name is required after .")

  defp classify!("." <> name, _pos, _parent, _state), do: {:local, name}

  defp classify!(<<first, _rest::binary>> = name, _pos, _parent, _state) when first in ?A..?Z,
    do: {:remote, name}

  defp classify!(name, _pos, _parent, _state), do: {:tag, name}

  defp attributes(rest, pos, state, acc) do
    case skip_space(rest, pos) do
      {"/>" <> rest, pos} ->
        {Enum.reverse(acc), :self, rest, advance(pos, 2)}

      {">" <> rest, pos} ->
        {Enum.reverse(acc), :open, rest, advance(pos, 1)}

      {"{" <> _rest, pos} ->
        syntax_error!(
          state,
          pos,
          "root attributes like {@rest} are not supported in GPUI templates"
        )

      {"", pos} ->
        syntax_error!(state, pos, "expected closing `>` or `/>`")

      {rest, pos} ->
        {attr, rest, pos} = attribute(rest, pos, state)
        attributes(rest, pos, state, [attr | acc])
    end
  end

  defp attribute(<<char, _rest::binary>>, pos, state) when char in [?", ?', ?}] do
    syntax_error!(state, pos, "invalid character in attribute name: #{<<char>>}")
  end

  defp attribute(rest, pos, state) do
    {name, rest, name_end} = name!(rest, pos, state, "expected attribute name")

    case skip_space(rest, name_end) do
      {"=" <> rest, eq_pos} ->
        {value, rest, value_end} = attribute_value(skip_space(rest, advance(eq_pos, 1)), state)
        {{name, value, meta(pos)}, rest, value_end}

      {_rest, _pos} ->
        syntax_error!(
          state,
          pos,
          "attribute #{name} requires a value; use #{name}={true} for a boolean attribute"
        )
    end
  end

  defp attribute_value({<<quote, rest::binary>>, pos}, state) when quote in [?", ?'] do
    quoted(rest, quote, advance(pos, 1), pos, state, [])
  end

  defp attribute_value({"{" <> rest, pos}, state) do
    expr_pos = advance(pos, 1)
    {code, rest, pos} = expression!(rest, expr_pos, pos, state)
    {{:expr, code, meta(expr_pos)}, rest, pos}
  end

  defp attribute_value({_rest, pos}, state) do
    syntax_error!(
      state,
      pos,
      "invalid attribute value after `=`. Expected a value between quotes " <>
        "(such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)"
    )
  end

  defp quoted(<<quote, rest::binary>>, quote, pos, _open_pos, _state, acc) do
    {{:string, reverse_string(acc)}, rest, advance(pos, 1)}
  end

  defp quoted("", quote, _pos, open_pos, state, _acc) do
    syntax_error!(state, open_pos, "expected closing `#{<<quote>>}` for attribute value")
  end

  defp quoted(rest, quote, pos, open_pos, state, acc) do
    {char, rest, pos} = next_char(rest, pos)
    quoted(rest, quote, pos, open_pos, state, [char | acc])
  end

  # Reads an expression body after its opening `{`, returning the code and the
  # input after the matching `}`.
  defp expression!(rest, pos, open_pos, state), do: expression(rest, pos, open_pos, state, 0, [])

  defp expression("}" <> rest, pos, _open_pos, _state, 0, acc),
    do: {reverse_string(acc), rest, advance(pos, 1)}

  defp expression(<<?\\, brace, rest::binary>>, pos, open_pos, state, depth, acc)
       when brace in [?{, ?}],
       do: expression(rest, advance(pos, 2), open_pos, state, depth, [brace, ?\\ | acc])

  defp expression("{" <> rest, pos, open_pos, state, depth, acc),
    do: expression(rest, advance(pos, 1), open_pos, state, depth + 1, [?{ | acc])

  defp expression("}" <> rest, pos, open_pos, state, depth, acc),
    do: expression(rest, advance(pos, 1), open_pos, state, depth - 1, [?} | acc])

  defp expression("", _pos, open_pos, state, _depth, _acc) do
    syntax_error!(
      state,
      open_pos,
      "expected closing `}` for expression. To render a literal `{`, use &lbrace; or {\"{\"}"
    )
  end

  defp expression(rest, pos, open_pos, state, depth, acc) do
    {char, rest, pos} = next_char(rest, pos)
    expression(rest, pos, open_pos, state, depth, [char | acc])
  end

  defp skip_comment("-->" <> rest, pos, _open_pos, _state), do: {rest, advance(pos, 3)}

  defp skip_comment("", _pos, open_pos, state),
    do: syntax_error!(state, open_pos, "expected closing `-->` for comment")

  defp skip_comment(rest, pos, open_pos, state) do
    {_char, rest, pos} = next_char(rest, pos)
    skip_comment(rest, pos, open_pos, state)
  end

  defp name!(rest, pos, state, message) do
    case take_name(rest, pos, []) do
      {[], _rest, _pos} -> syntax_error!(state, pos, message)
      {name, rest, pos} -> {reverse_string(name), rest, pos}
    end
  end

  defp take_name(<<char, _rest::binary>> = rest, pos, acc) when char in @name_stop_chars,
    do: {acc, rest, pos}

  defp take_name("", pos, acc), do: {acc, "", pos}

  defp take_name(rest, pos, acc) do
    {char, rest, pos} = next_char(rest, pos)
    take_name(rest, pos, [char | acc])
  end

  defp skip_space(<<char, rest::binary>>, pos) when char in @space_chars,
    do: skip_space(rest, advance(pos, 1))

  defp skip_space(<<char, _rest::binary>> = rest, pos) when char in [?\r, ?\n] do
    {_char, rest, pos} = next_char(rest, pos)
    skip_space(rest, pos)
  end

  defp skip_space(rest, pos), do: {rest, pos}

  defp next_char("\r\n" <> rest, {line, _column}), do: {"\r\n", rest, {line + 1, 1}}
  defp next_char("\n" <> rest, {line, _column}), do: {?\n, rest, {line + 1, 1}}
  defp next_char(<<char::utf8, rest::binary>>, pos), do: {<<char::utf8>>, rest, advance(pos, 1)}

  defp next_char(<<_byte, _rest::binary>>, _pos),
    do: raise(ArgumentError, "GPUI templates must be valid UTF-8")

  defp flush_text([], acc), do: acc

  defp flush_text(text, acc) do
    text = reverse_string(text)

    cond do
      String.trim(text) == "" -> acc
      # HEEx trims the text that follows a slot entry.
      match?([{:slot, _, _, _, _} | _], acc) -> [{:text, String.trim_leading(text)} | acc]
      true -> [{:text, text} | acc]
    end
  end

  defp reverse_string(chars), do: chars |> Enum.reverse() |> IO.iodata_to_binary()

  defp advance({line, column}, count), do: {line, column + count}

  defp meta({line, column}), do: %{line: line, column: column}

  defp syntax_error!(state, {line, column}, message) do
    raise CompileError, file: state.file, line: line, description: "#{message} (column #{column})"
  end
end
