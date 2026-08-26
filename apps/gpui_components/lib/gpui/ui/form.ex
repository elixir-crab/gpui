defmodule GPUI.UI.Form do
  @moduledoc "Renderer-independent composition for labeled form fields and feedback."

  alias GPUI.Element

  @allowed_attrs [:children, :class, :error, :help, :label, :required, :style]

  @spec field(map()) :: Element.t()
  def field(assigns) when is_map(assigns) do
    validate_attrs!(assigns)

    label = required_string!(assigns, :label)
    help = optional_string!(assigns, :help)
    error = optional_string!(assigns, :error)
    required = Map.get(assigns, :required, false)
    children = Map.get(assigns, :children, [])

    unless is_boolean(required) do
      raise ArgumentError,
            "GPUI.UI.field/1 :required must be a boolean; got: #{inspect(required)}"
    end

    unless match?([%Element{}], children) do
      raise ArgumentError, "GPUI.UI.field/1 requires exactly one element child"
    end

    [control] = children

    %Element{
      type: :div,
      attrs: wrapper_attrs(assigns),
      children:
        [
          text(if(required, do: "#{label} (required)", else: label)),
          control,
          feedback(error, help)
        ]
        |> Enum.reject(&is_nil/1)
    }
  end

  def field(assigns) do
    raise ArgumentError, "GPUI.UI.field/1 expects a map; got: #{inspect(assigns)}"
  end

  defp feedback(error, _help) when is_binary(error),
    do: text("Error: #{error}", color: {:rgb, 0xEF4444})

  defp feedback(nil, help) when is_binary(help), do: text(help)
  defp feedback(nil, nil), do: nil

  defp text(content, style \\ []) do
    %Element{
      type: :text,
      attrs: if(style == [], do: [], else: [style: style]),
      children: [content]
    }
  end

  defp wrapper_attrs(assigns) do
    style = Map.get(assigns, :style, [])

    unless is_list(style) or is_map(style) do
      raise ArgumentError,
            "GPUI.UI.field/1 :style must be a keyword list or map; got: #{inspect(style)}"
    end

    case Map.get(assigns, :class) do
      nil ->
        if(style in [[], %{}], do: [], else: [style: style])

      class when is_binary(class) ->
        %{style: class_style, unknown: unknown} = GPUI.Tailwind.normalize(class)
        merged_style = merge_styles(class_style, style)

        []
        |> put_attr(:style, merged_style, merged_style not in [[], %{}])
        |> put_attr(:class, Enum.join(unknown, " "), unknown != [])

      class ->
        raise ArgumentError, "GPUI.UI.field/1 :class must be a string; got: #{inspect(class)}"
    end
  end

  defp merge_styles(class_style, style) when is_list(style), do: Keyword.merge(class_style, style)

  defp merge_styles(class_style, style) when is_map(style),
    do: Map.merge(Map.new(class_style), style)

  defp put_attr(attrs, _name, _value, false), do: attrs
  defp put_attr(attrs, name, value, true), do: Keyword.put(attrs, name, value)

  defp validate_attrs!(assigns) do
    case Map.keys(assigns) -- @allowed_attrs do
      [] ->
        :ok

      attrs ->
        raise ArgumentError,
              "GPUI.UI.field/1 received unsupported attributes: #{inspect(Enum.sort(attrs))}"
    end
  end

  defp required_string!(assigns, name) do
    case Map.get(assigns, name) do
      value when is_binary(value) and value != "" ->
        value

      value ->
        raise ArgumentError,
              "GPUI.UI.field/1 :#{name} must be a non-empty string; got: #{inspect(value)}"
    end
  end

  defp optional_string!(assigns, name) do
    case Map.get(assigns, name) do
      nil ->
        nil

      value when is_binary(value) and value != "" ->
        value

      value ->
        raise ArgumentError,
              "GPUI.UI.field/1 :#{name} must be a non-empty string or nil; got: #{inspect(value)}"
    end
  end
end
