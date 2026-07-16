defmodule GPUI.UI do
  @moduledoc """
  Namespaced wrappers for native GPUI Component controls.

  Components are controlled by Elixir assigns and require a stable `:id` so
  native focus, animation, and interaction state survives rerenders.
  """

  alias GPUI.Element

  @doc "Builds a native GPUI Component button."
  @spec button(map()) :: Element.t()
  def button(assigns), do: component(:ui_button, assigns)

  @doc "Builds a native GPUI Component checkbox."
  @spec checkbox(map()) :: Element.t()
  def checkbox(assigns), do: component(:ui_checkbox, assigns)

  @doc "Builds a persistent native GPUI Component input."
  @spec input(map()) :: Element.t()
  def input(assigns), do: component(:ui_input, assigns)

  @doc """
  Builds a persistent native GPUI Component select.

  Options may be strings, `{label, value}` tuples, or maps with string `:label`
  and `:value` fields.
  """
  @spec select(map()) :: Element.t()
  def select(assigns), do: component(:ui_select, normalize_options_assigns!(:ui_select, assigns))

  @doc """
  Builds a persistent searchable GPUI Component combobox.

  Selection changes use `phx-change`; search text changes use `phx-search`.
  Options use the same format as `select/1`.
  """
  @spec combobox(map()) :: Element.t()
  def combobox(assigns),
    do: component(:ui_combobox, normalize_options_assigns!(:ui_combobox, assigns))

  defp normalize_options_assigns!(type, %{options: options} = assigns) when is_list(options) do
    options = normalize_options!(type, options)
    values = Enum.map(options, & &1.value)

    if length(values) != MapSet.size(MapSet.new(values)) do
      raise ArgumentError, "#{type} option values must be unique"
    end

    value = Map.get(assigns, :value)

    if type == :ui_select and not is_nil(value) and value not in values do
      raise ArgumentError, "#{type} value #{inspect(value)} is not present in options"
    end

    assigns
    |> Map.put(:options, options)
    |> then(fn assigns ->
      if is_nil(Map.get(assigns, :value)), do: Map.delete(assigns, :value), else: assigns
    end)
  end

  defp normalize_options_assigns!(type, _assigns),
    do: raise(ArgumentError, "#{type} requires an options list")

  defp normalize_options!(type, options) do
    Enum.map(options, fn
      option when is_binary(option) and option != "" ->
        %{label: option, value: option}

      {label, value} when is_binary(label) and label != "" and is_binary(value) and value != "" ->
        %{label: label, value: value}

      %{label: label, value: value}
      when is_binary(label) and label != "" and is_binary(value) and value != "" ->
        %{label: label, value: value}

      invalid ->
        raise ArgumentError,
              "invalid #{type} option #{inspect(invalid)}; expected a string, " <>
                "{label, value}, or %{label: label, value: value}"
    end)
  end

  defp component(type, %{id: id} = assigns) when is_binary(id) and id != "" do
    %Element{
      type: type,
      attrs: assigns |> Map.delete(:children) |> Map.to_list(),
      children: Map.get(assigns, :children, [])
    }
  end

  defp component(type, _assigns) do
    raise ArgumentError, "#{type} requires a non-empty string id"
  end
end
