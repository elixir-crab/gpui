defmodule GPUI.Template do
  @moduledoc """
  HEEx-style template support for GPUI.

  This module intentionally reuses `Phoenix.LiveView.TagEngine.Parser` for the
  HEEx-compatible tokenizer/tree builder, then compiles the parsed tree into
  `%GPUI.Element{}` values instead of `%Phoenix.LiveView.Rendered{}`.
  """

  alias GPUI.Element
  alias Phoenix.LiveView.TagEngine.Parser

  @doc "Compiles a HEEx-style GPUI template into an element tree."
  defmacro sigil_GPUI({:<<>>, meta, [source]}, _modifiers) when is_binary(source) do
    compile(source, __CALLER__, meta)
  end

  @spec compile(String.t(), Macro.Env.t(), keyword()) :: Macro.t()
  def compile(source, caller, meta \\ []) do
    %Parser{nodes: nodes} =
      Parser.parse!(source,
        caller: caller,
        file: caller.file || "nofile",
        line: Keyword.get(meta, :line, caller.line),
        tag_handler: GPUI.HTMLEngine
      )

    case Enum.reject(nodes, &blank_text?/1) do
      [node] -> compile_node(node, caller)
      nodes -> quote(do: unquote(Enum.map(nodes, &compile_node(&1, caller))))
    end
  end

  defp compile_node({:block, :tag, name, attrs, children, _open_meta, _close_meta}, caller) do
    quote do
      %Element{
        type: unquote(tag_atom(name)),
        attrs: unquote(compile_attrs(attrs)),
        children:
          List.flatten(
            unquote(
              children
              |> Enum.reject(&blank_text?/1)
              |> Enum.map(&compile_node(&1, caller))
            )
          )
      }
    end
  end

  defp compile_node({:self_close, :tag, name, attrs, _meta}, _caller) do
    quote do
      %Element{
        type: unquote(tag_atom(name)),
        attrs: unquote(compile_attrs(attrs)),
        children: []
      }
    end
  end

  defp compile_node(
         {:block, component_type, name, attrs, children, _open_meta, _close_meta},
         caller
       )
       when component_type in [:remote_component, :local_component] do
    children = children |> Enum.reject(&blank_text?/1) |> Enum.map(&compile_node(&1, caller))
    component_call(component_type, name, attrs, children, caller)
  end

  defp compile_node({:self_close, component_type, name, attrs, _meta}, caller)
       when component_type in [:remote_component, :local_component] do
    component_call(component_type, name, attrs, [], caller)
  end

  defp compile_node({:text, text, _meta}, _caller), do: text

  defp compile_node({:body_expr, expr, meta}, _caller) do
    Code.string_to_quoted!(expr, line: meta.line, column: meta.column)
  end

  defp compile_node({:eex, _type, expr, meta}, _caller) do
    Code.string_to_quoted!(expr, line: meta.line, column: meta.column)
  end

  defp component_call(:remote_component, name, attrs, children, _caller) do
    {module, function} = remote_component_target(name)

    quote do
      unquote(module).unquote(function)(
        GPUI.Component.assigns(unquote(compile_attrs(attrs)), List.flatten(unquote(children)))
      )
    end
  end

  defp component_call(:local_component, name, attrs, children, caller) do
    function = compile_time_atom(name)
    module = caller.module

    quote do
      unquote(module).unquote(function)(
        GPUI.Component.assigns(unquote(compile_attrs(attrs)), List.flatten(unquote(children)))
      )
    end
  end

  defp remote_component_target(name) do
    parts = String.split(name, ".")
    last = List.last(parts)

    if function_name?(last) and match?([_, _ | _], parts) do
      module = parts |> Enum.drop(-1) |> Module.concat()
      {module, compile_time_atom(last)}
    else
      {Module.concat(parts), :render}
    end
  end

  defp function_name?(<<first, _rest::binary>>), do: first in ?a..?z or first == ?_
  defp function_name?(""), do: false

  defp tag_atom("button"), do: :button
  defp tag_atom("div"), do: :div
  defp tag_atom("icon"), do: :icon
  defp tag_atom("img"), do: :img
  defp tag_atom("input"), do: :input
  defp tag_atom("item"), do: :item
  defp tag_atom("list"), do: :list
  defp tag_atom("scroll"), do: :scroll
  defp tag_atom("span"), do: :span
  defp tag_atom("text"), do: :text

  defp tag_atom(name) do
    raise ArgumentError, "unsupported GPUI tag #{inspect(name)}"
  end

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

  defp compile_attrs(attrs) do
    attrs
    |> Enum.map(fn {name, value, _meta} ->
      {attr_atom(to_string(name)), compile_attr_value(value)}
    end)
    |> normalize_class_attr()
  end

  defp normalize_class_attr(attrs) do
    case Keyword.fetch(attrs, :class) do
      {:ok, class} when is_binary(class) ->
        %{style: style, unknown: unknown} = GPUI.Tailwind.normalize(class)

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
    Keyword.update(attrs, :style, style, &Keyword.merge(&1, style))
  end

  defp put_unknown_class_attr(attrs, []), do: attrs

  defp put_unknown_class_attr(attrs, unknown),
    do: Keyword.put(attrs, :class, Enum.join(unknown, " "))

  defp compile_attr_value({:string, value, _meta}), do: value

  defp compile_attr_value({:expr, expr, meta}) do
    Code.string_to_quoted!(expr, line: meta.line, column: meta.column)
  end

  defp blank_text?({:text, text, _meta}), do: String.trim(text) == ""
  defp blank_text?(_node), do: false
end
