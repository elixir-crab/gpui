defmodule GPUI.UI do
  @moduledoc """
  Namespaced wrappers for native GPUI controls and collection primitives.

  Components are controlled by Elixir assigns and require a stable `:id` so
  native focus, animation, and interaction state survives rerenders.
  """

  alias GPUI.Element

  @max_file_bytes 100 * 1_024 * 1_024

  @type file_picker_value ::
          %{
            operation_id: non_neg_integer(),
            status: :selected,
            name: String.t(),
            size: non_neg_integer(),
            data: binary()
          }
          | %{operation_id: non_neg_integer(), status: :cancelled}
          | %{operation_id: non_neg_integer(), status: :error, reason: String.t()}

  @doc "Builds a native GPUI Component button."
  @spec button(map()) :: Element.t()
  def button(assigns), do: component(:ui_button, assigns)

  @doc """
  Builds an accessible controlled progress indicator.

  `value` defaults to zero, `max` defaults to 100, and `indeterminate` enables
  native loading animation while preserving the textual accessibility label.
  """
  @spec progress(map()) :: Element.t()
  def progress(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> Map.put_new(:value, 0.0)
      |> Map.put_new(:max, 100.0)
      |> Map.put_new(:indeterminate, false)

    validate_non_empty_label!(:ui_progress, Map.get(assigns, :label))

    unless is_number(assigns.max) and assigns.max > 0 do
      raise ArgumentError, "ui_progress max must be greater than zero"
    end

    unless is_number(assigns.value) and assigns.value >= 0 and assigns.value <= assigns.max do
      raise ArgumentError, "ui_progress value must be between zero and max"
    end

    component(:ui_progress, assigns)
  end

  @doc """
  Builds a display-side file picker that emits selected file bytes through `phx-change`.

  The event value is a selected-file, cancellation, or error map described by
  `file_picker_value/0`. Bytes are read on the display machine, bounded by
  `max_bytes`, and can therefore cross a remote display connection without
  exposing an unusable client-local path.
  """
  @spec file_picker(map()) :: Element.t()
  def file_picker(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> Map.put_new(:max_bytes, 25 * 1_024 * 1_024)
      |> Map.put_new(:disabled, false)

    validate_non_empty_label!(:ui_file_picker, Map.get(assigns, :label))
    validate_event!(:ui_file_picker, assigns, :"phx-change")

    unless is_integer(assigns.max_bytes) and assigns.max_bytes > 0 and
             assigns.max_bytes <= @max_file_bytes do
      raise ArgumentError, "ui_file_picker max_bytes must be between 1 and #{@max_file_bytes}"
    end

    component(:ui_file_picker, assigns)
  end

  @doc """
  Builds a button that writes text to the display-side clipboard before `phx-click`.

  Clipboard ownership follows the renderer, so remote clients write to the
  user's clipboard rather than the application server's clipboard.
  """
  @spec copy_button(map()) :: Element.t()
  def copy_button(assigns) when is_map(assigns) do
    assigns = Map.put_new(assigns, :disabled, false)
    validate_non_empty_label!(:ui_copy_button, Map.get(assigns, :label))
    validate_event!(:ui_copy_button, assigns, :"phx-click")

    unless is_binary(Map.get(assigns, :text)) do
      raise ArgumentError, "ui_copy_button requires string text"
    end

    component(:ui_copy_button, assigns)
  end

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

  defp validate_non_empty_label!(_component, label) when is_binary(label) and label != "", do: :ok

  defp validate_non_empty_label!(component, _label),
    do: raise(ArgumentError, "#{component} requires a non-empty string label")

  defp validate_event!(component, assigns, event) do
    value = Map.get(assigns, event) || Map.get(assigns, Atom.to_string(event))

    unless is_binary(value) and value != "" do
      raise ArgumentError, "#{component} requires #{event}"
    end
  end

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

  Source-backed lists set `total_count`, `offset`, and `phx-range`. Their
  children are a contiguous loaded slice beginning at `offset`; native scroll
  and resize changes emit an overscanned `%{first: first, last: last}` range,
  where `last` is exclusive. `selected_index` and `reveal_index` preserve
  controlled identity and scrolling when those rows are not currently loaded.
  """
  @spec virtual_list(map()) :: Element.t()
  def virtual_list(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:item_height, 40.0)
      |> Map.put_new(:reveal_strategy, "nearest")
      |> Map.put_new(:total_count, length(children))
      |> Map.put_new(:offset, 0)
      |> Map.put_new(:overscan, 8)
      |> Map.put_new(:disabled, false)

    item_ids = virtual_list_item_ids!(children)
    validate_virtual_list!(assigns, item_ids)

    assigns = drop_nil_attrs(assigns, [:selected, :selected_index, :reveal, :reveal_index])
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
    validate_source_range!(assigns, item_ids)

    if source_backed_virtual_list?(assigns, item_ids) do
      validate_source_selection!(assigns, item_ids, :selected, :selected_index)
      validate_source_selection!(assigns, item_ids, :reveal, :reveal_index)
    else
      if Map.get(assigns, :selected_index) || Map.get(assigns, :reveal_index) do
        raise ArgumentError,
              "ui_virtual_list controlled indexes require a source-backed list with phx-range"
      end

      validate_controlled_item!(:selected, Map.get(assigns, :selected), item_ids)
      validate_controlled_item!(:reveal, Map.get(assigns, :reveal), item_ids)
    end
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

  defp validate_source_range!(assigns, item_ids) do
    validate_non_negative_integer!(:total_count, assigns.total_count)
    validate_non_negative_integer!(:overscan, assigns.overscan)
    validate_source_offset!(assigns.offset, assigns.total_count)
    validate_loaded_count!(assigns.offset, length(item_ids), assigns.total_count)

    if source_backed_virtual_list?(assigns, item_ids) do
      validate_event!(:ui_virtual_list, assigns, :"phx-range")
    end
  end

  defp validate_non_negative_integer!(_name, value) when is_integer(value) and value >= 0,
    do: :ok

  defp validate_non_negative_integer!(name, _value),
    do: raise(ArgumentError, "ui_virtual_list #{name} must be a non-negative integer")

  defp validate_source_offset!(offset, total_count)
       when is_integer(offset) and offset >= 0 and offset <= total_count,
       do: :ok

  defp validate_source_offset!(_offset, _total_count),
    do: raise(ArgumentError, "ui_virtual_list offset must be between zero and total_count")

  defp validate_loaded_count!(offset, count, total_count) when offset + count <= total_count,
    do: :ok

  defp validate_loaded_count!(_offset, _count, _total_count),
    do: raise(ArgumentError, "ui_virtual_list loaded slice exceeds total_count")

  defp source_backed_virtual_list?(assigns, item_ids),
    do:
      not is_nil(Map.get(assigns, :"phx-range")) or assigns.offset != 0 or
        assigns.total_count != length(item_ids)

  defp validate_source_selection!(assigns, item_ids, value_name, index_name) do
    value = Map.get(assigns, value_name)
    index = Map.get(assigns, index_name)

    validate_source_value!(value_name, value)
    validate_source_index!(index_name, index, assigns.total_count)
    validate_source_pair!(value_name, index_name, value, index)
    validate_loaded_identity!(assigns, item_ids, value_name, index_name, value, index)
  end

  defp validate_source_value!(_name, nil), do: :ok
  defp validate_source_value!(_name, value) when is_binary(value) and value != "", do: :ok

  defp validate_source_value!(name, _value),
    do: raise(ArgumentError, "ui_virtual_list #{name} must be a non-empty string")

  defp validate_source_index!(_name, nil, _total_count), do: :ok

  defp validate_source_index!(_name, index, total_count)
       when is_integer(index) and index >= 0 and index < total_count,
       do: :ok

  defp validate_source_index!(name, _index, _total_count),
    do:
      raise(
        ArgumentError,
        "ui_virtual_list #{name} must identify an index below total_count"
      )

  defp validate_source_pair!(_value_name, _index_name, nil, nil), do: :ok

  defp validate_source_pair!(_value_name, _index_name, value, index)
       when not is_nil(value) and not is_nil(index), do: :ok

  defp validate_source_pair!(value_name, index_name, _value, _index),
    do:
      raise(
        ArgumentError,
        "ui_virtual_list #{value_name} and #{index_name} must be provided together"
      )

  defp validate_loaded_identity!(assigns, item_ids, value_name, index_name, value, index) do
    loaded? =
      is_integer(index) and index >= assigns.offset and
        index < assigns.offset + length(item_ids)

    if loaded? and Enum.at(item_ids, index - assigns.offset) != value do
      raise ArgumentError,
            "ui_virtual_list #{value_name} does not match the loaded item at #{index_name}"
    end
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

  defp normalize_attr_key(assigns, key) do
    case Map.pop(assigns, Atom.to_string(key)) do
      {nil, assigns} -> assigns
      {value, assigns} -> Map.put_new(assigns, key, value)
    end
  end

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
