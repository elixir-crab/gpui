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
  def select(%{options: options} = assigns) when is_list(options) do
    options = normalize_select_options!(options)
    values = Enum.map(options, & &1.value)

    if length(values) != MapSet.size(MapSet.new(values)) do
      raise ArgumentError, "ui_select option values must be unique"
    end

    value = Map.get(assigns, :value)

    if not is_nil(value) and value not in values do
      raise ArgumentError, "ui_select value #{inspect(value)} is not present in options"
    end

    assigns =
      assigns
      |> Map.put(:options, options)
      |> then(fn assigns ->
        if is_nil(Map.get(assigns, :value)), do: Map.delete(assigns, :value), else: assigns
      end)

    component(:ui_select, assigns)
  end

  def select(_assigns), do: raise(ArgumentError, "ui_select requires an options list")

  defp normalize_select_options!(options) do
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
              "invalid ui_select option #{inspect(invalid)}; expected a string, " <>
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
