defmodule GPUI.UI do
  @moduledoc """
  Namespaced wrappers for native GPUI controls and collection primitives.

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

  @doc "Builds a controlled boolean GPUI Component switch."
  @spec switch(map()) :: Element.t()
  def switch(assigns), do: component(:ui_switch, assigns)

  @doc """
  Builds a controlled GPUI Component radio group.

  Options accept the same forms as `select/1`. Map options may additionally set
  `disabled: true`.
  """
  @spec radio_group(map()) :: Element.t()
  def radio_group(%{options: options} = assigns) when is_list(options) do
    options = Enum.map(options, &normalize_radio_option!/1)
    values = Enum.map(options, & &1.value)

    if length(values) != MapSet.size(MapSet.new(values)) do
      raise ArgumentError, "ui_radio_group option values must be unique"
    end

    value = Map.get(assigns, :value)

    if is_nil(value) or value not in values do
      raise ArgumentError,
            "ui_radio_group value #{inspect(value)} is not present in options"
    end

    component(:ui_radio_group, Map.put(assigns, :options, options))
  end

  def radio_group(_assigns),
    do: raise(ArgumentError, "ui_radio_group requires an options list")

  defp normalize_radio_option!(%{disabled: disabled} = option) when is_boolean(disabled) do
    option
    |> Map.delete(:disabled)
    |> then(&normalize_options!(:ui_radio_group, [&1]))
    |> hd()
    |> Map.put(:disabled, disabled)
  end

  defp normalize_radio_option!(option) do
    :ui_radio_group
    |> normalize_options!([option])
    |> hd()
    |> Map.put(:disabled, false)
  end

  @doc """
  Builds a controlled GPUI Component accordion from `accordion_item/1` children.

  `expanded` contains the stable item IDs currently open. Changes emit the new
  list through `phx-change`.
  """
  @spec accordion(map()) :: Element.t()
  def accordion(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> Map.put_new(:expanded, [])
      |> Map.put_new(:multiple, false)
      |> Map.put_new(:bordered, true)

    expanded = assigns.expanded
    children = Map.get(assigns, :children, [])

    unless is_list(expanded) and Enum.all?(expanded, &(is_binary(&1) and &1 != "")) do
      raise ArgumentError, "ui_accordion expanded must be a list of non-empty string IDs"
    end

    unless length(expanded) == MapSet.size(MapSet.new(expanded)) do
      raise ArgumentError, "ui_accordion expanded IDs must be unique"
    end

    item_ids =
      Enum.map(children, fn
        %Element{type: :ui_accordion_item, attrs: attrs} ->
          Map.fetch!(Map.new(attrs), :id)

        child ->
          raise ArgumentError,
                "ui_accordion only accepts accordion_item children, got: #{inspect(child)}"
      end)

    unless Enum.all?(expanded, &(&1 in item_ids)) do
      raise ArgumentError, "ui_accordion expanded IDs must identify accordion items"
    end

    if not assigns.multiple and match?([_, _ | _], expanded) do
      raise ArgumentError, "ui_accordion requires multiple={true} for multiple expanded items"
    end

    component(:ui_accordion, assigns)
  end

  @doc "Builds an item for `accordion/1`."
  @spec accordion_item(map()) :: Element.t()
  def accordion_item(%{title: title} = assigns) when is_binary(title) and title != "",
    do: component(:ui_accordion_item, assigns)

  def accordion_item(_assigns),
    do: raise(ArgumentError, "ui_accordion_item requires a non-empty string title")

  @doc """
  Builds a controlled, virtualized list of uniform-height `virtual_list_item/1` children.

  Only the visible item range is rendered natively. `selected` identifies the
  controlled selection, while `reveal` requests that an item be scrolled into
  view using `reveal_strategy`. Selection changes are emitted through
  `phx-change`.
  """
  @spec virtual_list(map()) :: Element.t()
  def virtual_list(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> Map.put_new(:item_height, 40.0)
      |> Map.put_new(:reveal_strategy, "nearest")
      |> Map.put_new(:disabled, false)

    item_ids = virtual_list_item_ids!(Map.get(assigns, :children, []))
    validate_virtual_list!(assigns, item_ids)

    assigns = drop_nil_attrs(assigns, [:selected, :reveal])
    component(:ui_virtual_list, assigns)
  end

  @doc "Builds a stable row for `virtual_list/1`."
  @spec virtual_list_item(map()) :: Element.t()
  def virtual_list_item(assigns) when is_map(assigns),
    do: component(:ui_virtual_list_item, Map.put_new(assigns, :disabled, false))

  defp virtual_list_item_ids!(children) do
    item_ids =
      Enum.map(children, fn
        %Element{type: :ui_virtual_list_item, attrs: attrs} ->
          Map.fetch!(Map.new(attrs), :id)

        child ->
          raise ArgumentError,
                "ui_virtual_list only accepts virtual_list_item children, got: #{inspect(child)}"
      end)

    if item_ids != Enum.uniq(item_ids) do
      raise ArgumentError, "ui_virtual_list item IDs must be unique"
    end

    item_ids
  end

  defp validate_virtual_list!(assigns, item_ids) do
    validate_virtual_list_label!(Map.get(assigns, :label))
    validate_item_height!(assigns.item_height)
    validate_reveal_strategy!(assigns.reveal_strategy)
    validate_controlled_item!(:selected, Map.get(assigns, :selected), item_ids)
    validate_controlled_item!(:reveal, Map.get(assigns, :reveal), item_ids)
  end

  defp validate_virtual_list_label!(label) when is_binary(label) and label != "", do: :ok

  defp validate_virtual_list_label!(_label),
    do: raise(ArgumentError, "ui_virtual_list requires a non-empty string label")

  defp validate_item_height!(height) when is_number(height) and height > 0, do: :ok

  defp validate_item_height!(_height),
    do: raise(ArgumentError, "ui_virtual_list item_height must be greater than zero")

  defp validate_reveal_strategy!(strategy) when strategy in ~w(nearest top center bottom), do: :ok

  defp validate_reveal_strategy!(_strategy) do
    raise ArgumentError, "ui_virtual_list reveal_strategy must be nearest, top, center, or bottom"
  end

  defp validate_controlled_item!(_name, nil, _item_ids), do: :ok

  defp validate_controlled_item!(name, value, item_ids) when is_binary(value) do
    if value in item_ids do
      :ok
    else
      raise ArgumentError, "ui_virtual_list #{name} must identify a virtual_list_item child"
    end
  end

  defp validate_controlled_item!(name, _value, _item_ids),
    do: raise(ArgumentError, "ui_virtual_list #{name} must identify a virtual_list_item child")

  defp drop_nil_attrs(attrs, names) do
    Enum.reduce(names, attrs, fn name, attrs ->
      if is_nil(Map.get(attrs, name)), do: Map.delete(attrs, name), else: attrs
    end)
  end

  @doc """
  Builds a controlled GPUI Component tab bar.

  Options use the same label/value format as `select/1`; `value` identifies the
  selected tab and changes are emitted through `phx-change`.
  """
  @spec tabs(map()) :: Element.t()
  def tabs(assigns) do
    assigns = normalize_options_assigns!(:ui_tabs, assigns)
    values = Enum.map(assigns.options, & &1.value)

    if is_nil(Map.get(assigns, :value)) or assigns.value not in values do
      raise ArgumentError,
            "ui_tabs value #{inspect(Map.get(assigns, :value))} is not present in options"
    end

    component(:ui_tabs, assigns)
  end

  @doc """
  Builds a persistent controlled GPUI Component slider.

  `phx-change` is emitted continuously during pointer interaction and
  `phx-release` is emitted once interaction finishes.
  """
  @spec slider(map()) :: Element.t()
  def slider(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> Map.put_new(:value, 0.0)
      |> Map.put_new(:min, 0.0)
      |> Map.put_new(:max, 100.0)
      |> Map.put_new(:step, 1.0)
      |> Map.put_new(:orientation, "horizontal")
      |> Map.put_new(:scale, "linear")
      |> normalize_slider_numbers!()

    validate_slider!(assigns)
    component(:ui_slider, assigns)
  end

  defp normalize_slider_numbers!(assigns) do
    Enum.reduce([:value, :min, :max, :step], assigns, fn name, normalized ->
      case Map.fetch!(normalized, name) do
        value when is_number(value) -> Map.put(normalized, name, value / 1)
        value -> raise ArgumentError, "ui_slider #{name} must be a number, got: #{inspect(value)}"
      end
    end)
  end

  defp validate_slider!(assigns) do
    cond do
      assigns.min >= assigns.max ->
        raise ArgumentError, "ui_slider min must be less than max"

      assigns.step <= 0 ->
        raise ArgumentError, "ui_slider step must be greater than zero"

      assigns.value < assigns.min or assigns.value > assigns.max ->
        raise ArgumentError, "ui_slider value must be between min and max"

      assigns.scale == "logarithmic" and assigns.min <= 0 ->
        raise ArgumentError, "ui_slider logarithmic scale requires min greater than zero"

      true ->
        :ok
    end
  end

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
