defmodule GPUI.Template do
  @moduledoc """
  HEEx-style template support for GPUI.

  Templates use the element subset of HEEx syntax: tags, `<Remote.component>`
  and `<.local_component>` calls, `<:slot>` entries, and `{expression}`
  attribute values and children. They compile into `%GPUI.Element{}` trees at
  compile time. EEx tags (`<%= %>`), `:if`/`:for`, and root attributes such as
  `{@rest}` are not supported; use ordinary Elixir expressions instead.

  Lowercase tags are renderer primitives. Native components use `GPUI.UI` or
  `GPUI.UI.Overlay`; their internal `ui_*` element tags are intentionally not a
  public template surface.
  """

  alias GPUI.Element
  alias GPUI.Template.Parser

  @primitive_tag_lookup GPUI.Schema.components()
                        |> Enum.reject(&String.starts_with?(Atom.to_string(&1.tag), "ui_"))
                        |> Map.new(&{Atom.to_string(&1.tag), &1.tag})

  @doc "Compiles a HEEx-style GPUI template into an element tree."
  defmacro sigil_GPUI({:<<>>, meta, [source]}, _modifiers) when is_binary(source) do
    compile(source, __CALLER__, meta)
  end

  @spec compile(String.t(), Macro.Env.t(), keyword()) :: Macro.t()
  def compile(source, caller, meta \\ []) do
    nodes =
      Parser.parse!(source,
        file: caller.file || "nofile",
        line: Keyword.get(meta, :line, caller.line)
      )

    case nodes do
      [node] -> compile_node(node, caller)
      [] -> raise ArgumentError, "GPUI templates require one root element"
      _nodes -> raise ArgumentError, "GPUI templates require exactly one root element"
    end
  end

  defp compile_node({:tag, name, attrs, children, meta}, caller) do
    quote do
      %Element{
        type: unquote(tag_atom(name, caller, meta)),
        attrs: unquote(compile_attrs(attrs, caller)),
        children: unquote(flat_children(children, caller))
      }
    end
  end

  defp compile_node({:component, kind, name, attrs, children, _meta}, caller) do
    {slots, children} = Enum.split_with(children, &match?({:slot, _, _, _, _}, &1))

    component_call(
      kind,
      name,
      attrs,
      compile_children(children, caller),
      compile_slots(slots, caller),
      caller
    )
  end

  defp compile_node({:text, text}, _caller), do: text

  defp compile_node({:expr, code, meta}, caller), do: compile_expr(code, meta, caller)

  defp compile_children(children, caller), do: Enum.map(children, &compile_node(&1, caller))

  defp flat_children([], _caller), do: []

  defp flat_children(children, caller) do
    quote do: List.flatten(unquote(compile_children(children, caller)))
  end

  defp compile_expr(code, meta, caller) do
    Code.string_to_quoted!(code,
      file: caller.file || "nofile",
      line: meta.line,
      column: meta.column
    )
  end

  defp component_call(:remote, name, attrs, children, slots, caller) do
    {module, function} = remote_component_target(name, caller)

    quote do
      unquote(module).unquote(function)(
        GPUI.Template.Component.assigns(
          unquote(compile_attrs(attrs, caller)),
          List.flatten(unquote(children)),
          unquote(slots)
        )
      )
    end
  end

  defp component_call(:local, name, attrs, children, slots, caller) do
    function = compile_time_atom(name)
    module = caller.module

    quote do
      unquote(module).unquote(function)(
        GPUI.Template.Component.assigns(
          unquote(compile_attrs(attrs, caller)),
          List.flatten(unquote(children)),
          unquote(slots)
        )
      )
    end
  end

  defp compile_slots(slots, caller) do
    Enum.map(slots, fn {:slot, name, attrs, children, _meta} ->
      slot =
        quote do
          %GPUI.Template.Component.Slot{
            attrs: unquote(compile_attrs(attrs, caller)),
            children: unquote(flat_children(children, caller))
          }
        end

      {compile_time_atom(name), slot}
    end)
  end

  defp remote_component_target(name, caller) do
    parts = String.split(name, ".")
    last = List.last(parts)

    if function_name?(last) and match?([_, _ | _], parts) do
      module = parts |> Enum.drop(-1) |> expand_component_module(caller)
      {module, compile_time_atom(last)}
    else
      {expand_component_module(parts, caller), :render}
    end
  end

  defp expand_component_module(parts, caller) do
    parts
    |> Enum.map(&compile_time_atom/1)
    |> then(&{:__aliases__, [], &1})
    |> Macro.expand(caller)
  end

  defp function_name?(<<first, _rest::binary>>), do: first in ?a..?z or first == ?_
  defp function_name?(""), do: false

  defp tag_atom(name, caller, meta) do
    case Map.fetch(@primitive_tag_lookup, name) do
      {:ok, tag} ->
        tag

      :error ->
        description =
          if String.starts_with?(name, "ui_") do
            "native component tag <#{name}> is internal; use #{component_builder(name)}"
          else
            "unsupported GPUI tag <#{name}>"
          end

        raise CompileError,
          file: caller.file,
          line: meta_line(meta, caller.line),
          description: description
    end
  end

  defp component_builder("ui_" <> name) when name in ~w(popover tooltip dialog dropdown_menu),
    do: "<GPUI.UI.Overlay.#{name}>"

  defp component_builder("ui_" <> name)
       when name in ~w(popover_trigger popover_content tooltip_trigger dialog_trigger dialog_content dropdown_menu_trigger dropdown_menu_item),
       do: "the corresponding GPUI.UI.Overlay builder"

  defp component_builder("ui_" <> name), do: "<GPUI.UI.#{name}>"

  defp attr_atom("class"), do: :class
  defp attr_atom("label"), do: :label
  defp attr_atom("phx-change"), do: :"phx-change"
  defp attr_atom("phx-click"), do: :"phx-click"
  defp attr_atom("raster"), do: :raster
  defp attr_atom("title"), do: :title
  defp attr_atom("value"), do: :value
  defp attr_atom(name), do: compile_time_atom(name)

  defp compile_time_atom(name) when is_binary(name) do
    if Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_?!-]*$/, name) do
      :erlang.binary_to_atom(name, :utf8)
    else
      raise ArgumentError, "invalid GPUI identifier #{inspect(name)}"
    end
  end

  defp compile_attrs(attrs, caller) do
    validate_unique_attrs!(attrs, caller)

    attrs
    |> Enum.map(fn {name, value, _meta} ->
      {attr_atom(name), compile_attr_value(value, caller)}
    end)
    |> normalize_class_attr()
  end

  defp validate_unique_attrs!(attrs, caller) do
    attrs
    |> Enum.group_by(fn {name, _value, _meta} -> name end)
    |> Enum.each(fn
      {_name, [_attr]} ->
        :ok

      {name, [_first, {_name, _value, meta} | _rest]} ->
        raise CompileError,
          file: caller.file,
          line: meta_line(meta, caller.line),
          description: "duplicate GPUI attribute #{inspect(name)}"
    end)
  end

  defp meta_line(%{line: line}, _fallback) when is_integer(line), do: line
  defp meta_line(meta, fallback) when is_list(meta), do: Keyword.get(meta, :line, fallback)
  defp meta_line(_meta, fallback), do: fallback

  defp normalize_class_attr(attrs) do
    case Keyword.fetch(attrs, :class) do
      {:ok, class} when is_binary(class) ->
        %{style: style, unknown: unknown} = GPUI.Tailwind.normalize(class)
        :ok = GPUI.Tailwind.handle_unknown!(unknown)

        attrs
        |> Keyword.delete(:class)
        |> put_style_attr(style)
        |> put_unknown_class_attr(unknown)

      _other ->
        attrs
    end
  end

  defp put_style_attr(attrs, []), do: attrs

  defp put_style_attr(attrs, style) do
    case Keyword.fetch(attrs, :style) do
      :error ->
        Keyword.put(attrs, :style, style)

      {:ok, existing} when is_list(existing) ->
        Keyword.put(attrs, :style, Keyword.merge(existing, style))

      {:ok, existing} ->
        merged =
          quote do
            Keyword.merge(unquote(existing), unquote(Macro.escape(style)))
          end

        Keyword.put(attrs, :style, merged)
    end
  end

  defp put_unknown_class_attr(attrs, []), do: attrs

  defp put_unknown_class_attr(attrs, unknown),
    do: Keyword.put(attrs, :class, Enum.join(unknown, " "))

  defp compile_attr_value({:string, value}, _caller), do: value
  defp compile_attr_value({:expr, code, meta}, caller), do: compile_expr(code, meta, caller)
end
