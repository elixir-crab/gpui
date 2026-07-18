defmodule GPUI.UI do
  @moduledoc """
  Namespaced wrappers for native GPUI controls and collection primitives.

  Components are controlled by Elixir assigns and require a stable `:id` so
  native focus, animation, and interaction state survives rerenders.
  """

  alias GPUI.Element
  alias GPUI.Schema

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
    assigns = Schema.apply_defaults(assigns, :ui_progress)

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
    assigns = Schema.apply_defaults(assigns, :ui_file_picker)

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
    assigns = Schema.apply_defaults(assigns, :ui_copy_button)
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
    assigns = Schema.apply_defaults(assigns, :ui_accordion)

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
      |> Map.put_new(:total_count, length(children))
      |> Schema.apply_defaults(:ui_virtual_list)

    item_ids = collection_item_ids!(:ui_virtual_list, :ui_virtual_list_item, children)
    validate_virtual_collection!(:ui_virtual_list, assigns, item_ids)

    component(:ui_virtual_list, assigns)
  end

  @doc "Builds a stable row for `virtual_list/1`."
  @spec virtual_list_item(map()) :: Element.t()
  def virtual_list_item(assigns) when is_map(assigns),
    do: component(:ui_virtual_list_item, Schema.apply_defaults(assigns, :ui_virtual_list_item))

  @doc """
  Builds an accessible controlled tree from uniform-height `tree_item/1` children.

  Trees support the same source-backed `total_count`, `offset`, `overscan`,
  selection-index, reveal-index, and `phx-range` contract as `virtual_list/1`.
  Selection emits an item ID through `phx-change`; branch expansion requests
  emit the branch ID through `phx-toggle`.
  """
  @spec tree(map()) :: Element.t()
  def tree(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:total_count, length(children))
      |> Schema.apply_defaults(:ui_tree)

    item_ids = collection_item_ids!(:ui_tree, :ui_tree_item, children)
    validate_virtual_collection!(:ui_tree, assigns, item_ids)
    validate_event!(:ui_tree, assigns, :"phx-change")
    validate_event!(:ui_tree, assigns, :"phx-toggle")

    component(:ui_tree, assigns)
  end

  @doc "Builds one accessible row for `tree/1`."
  @spec tree_item(map()) :: Element.t()
  def tree_item(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_tree_item)

    validate_tree_item!(assigns)
    component(:ui_tree_item, assigns)
  end

  @doc """
  Builds a source-backed monospaced code or unified-diff viewer.

  Lines are uniform-height `code_line/1` children. The viewer shares the
  selection, reveal, overscan, and exclusive `phx-range` contract used by
  `virtual_list/1`. `max_columns` preserves stable horizontal geometry for
  unloaded lines; Ctrl/Cmd+C copies the selected loaded line on the display
  machine and acknowledges `phx-copy` when configured.
  """
  @spec code_viewer(map()) :: Element.t()
  def code_viewer(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:total_count, length(children))
      |> Schema.apply_defaults(:ui_code_viewer)

    item_ids = collection_item_ids!(:ui_code_viewer, :ui_code_line, children)
    validate_virtual_collection!(:ui_code_viewer, assigns, item_ids)
    validate_non_negative_integer!(:ui_code_viewer, :max_columns, assigns.max_columns)

    if assigns.max_columns > 20_000 do
      raise ArgumentError, "ui_code_viewer max_columns must be at most 20000"
    end

    unless assigns.mode in ~w(plain diff) do
      raise ArgumentError, "ui_code_viewer mode must be plain or diff"
    end

    unless is_integer(assigns.tab_width) and assigns.tab_width in 1..16 do
      raise ArgumentError, "ui_code_viewer tab_width must be between 1 and 16"
    end

    component(:ui_code_viewer, assigns)
  end

  @doc "Builds one native line for `code_viewer/1`."
  @spec code_line(map()) :: Element.t()
  def code_line(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_code_line)

    unless is_binary(Map.get(assigns, :id)) and assigns.id != "" and
             is_binary(assigns.text) do
      raise ArgumentError, "ui_code_line requires non-empty string id and string text"
    end

    if byte_size(assigns.text) > 100_000 do
      raise ArgumentError, "ui_code_line text must be at most 100000 bytes"
    end

    unless is_nil(Map.get(assigns, :number)) or
             (is_integer(assigns.number) and assigns.number >= 0) do
      raise ArgumentError, "ui_code_line number must be a non-negative integer"
    end

    unless assigns.kind in ~w(context addition deletion hunk debug info warning error) do
      raise ArgumentError,
            "ui_code_line kind must be context, addition, deletion, hunk, debug, info, warning, or error"
    end

    component(:ui_code_line, assigns)
  end

  defp collection_item_ids!(component, item_type, children) do
    item_ids =
      Enum.map(children, fn
        %Element{type: ^item_type, attrs: attrs} ->
          Map.fetch!(Map.new(attrs), :id)

        child ->
          raise ArgumentError,
                "#{component} only accepts #{item_type} children, got: #{inspect(child)}"
      end)

    if item_ids != Enum.uniq(item_ids) do
      raise ArgumentError, "#{component} item IDs must be unique"
    end

    item_ids
  end

  defp validate_virtual_collection!(component, assigns, item_ids) do
    validate_collection_label!(component, Map.get(assigns, :label))
    validate_item_height!(component, assigns.item_height)
    validate_reveal_strategy!(component, assigns.reveal_strategy)
    validate_source_range!(component, assigns, item_ids)

    if source_backed_collection?(assigns, item_ids) do
      validate_source_selection!(component, assigns, item_ids, :selected, :selected_index)
      validate_source_selection!(component, assigns, item_ids, :reveal, :reveal_index)
    else
      validate_full_collection!(component, assigns, item_ids)
    end
  end

  defp validate_collection_label!(_component, label) when is_binary(label) and label != "",
    do: :ok

  defp validate_collection_label!(component, _label),
    do: raise(ArgumentError, "#{component} requires a non-empty string label")

  defp validate_item_height!(_component, height) when is_number(height) and height > 0, do: :ok

  defp validate_item_height!(component, _height),
    do: raise(ArgumentError, "#{component} item_height must be greater than zero")

  defp validate_reveal_strategy!(_component, strategy)
       when strategy in ~w(nearest top center bottom),
       do: :ok

  defp validate_reveal_strategy!(component, _strategy) do
    raise ArgumentError,
          "#{component} reveal_strategy must be nearest, top, center, or bottom"
  end

  defp validate_source_range!(component, assigns, item_ids) do
    validate_non_negative_integer!(component, :total_count, assigns.total_count)
    validate_non_negative_integer!(component, :overscan, assigns.overscan)
    validate_source_offset!(component, assigns.offset, assigns.total_count)
    validate_loaded_count!(component, assigns.offset, length(item_ids), assigns.total_count)

    if source_backed_collection?(assigns, item_ids) do
      validate_event!(component, assigns, :"phx-range")
    end
  end

  defp validate_non_negative_integer!(_component, _name, value)
       when is_integer(value) and value >= 0,
       do: :ok

  defp validate_non_negative_integer!(component, name, _value),
    do: raise(ArgumentError, "#{component} #{name} must be a non-negative integer")

  defp validate_source_offset!(_component, offset, total_count)
       when is_integer(offset) and offset >= 0 and offset <= total_count,
       do: :ok

  defp validate_source_offset!(component, _offset, _total_count),
    do: raise(ArgumentError, "#{component} offset must be between zero and total_count")

  defp validate_loaded_count!(_component, offset, count, total_count)
       when offset + count <= total_count,
       do: :ok

  defp validate_loaded_count!(component, _offset, _count, _total_count),
    do: raise(ArgumentError, "#{component} loaded slice exceeds total_count")

  defp source_backed_collection?(assigns, item_ids),
    do:
      not is_nil(Map.get(assigns, :"phx-range")) or assigns.offset != 0 or
        assigns.total_count != length(item_ids)

  defp validate_source_selection!(component, assigns, item_ids, value_name, index_name) do
    value = Map.get(assigns, value_name)
    index = Map.get(assigns, index_name)

    validate_source_value!(component, value_name, value)
    validate_source_index!(component, index_name, index, assigns.total_count)
    validate_source_pair!(component, value_name, index_name, value, index)
    validate_loaded_identity!(component, assigns, item_ids, value_name, index_name, value, index)
  end

  defp validate_source_value!(_component, _name, nil), do: :ok

  defp validate_source_value!(_component, _name, value) when is_binary(value) and value != "",
    do: :ok

  defp validate_source_value!(component, name, _value),
    do: raise(ArgumentError, "#{component} #{name} must be a non-empty string")

  defp validate_source_index!(_component, _name, nil, _total_count), do: :ok

  defp validate_source_index!(_component, _name, index, total_count)
       when is_integer(index) and index >= 0 and index < total_count,
       do: :ok

  defp validate_source_index!(component, name, _index, _total_count),
    do: raise(ArgumentError, "#{component} #{name} must identify an index below total_count")

  defp validate_source_pair!(_component, _value_name, _index_name, nil, nil), do: :ok

  defp validate_source_pair!(_component, _value_name, _index_name, value, index)
       when not is_nil(value) and not is_nil(index),
       do: :ok

  defp validate_source_pair!(component, value_name, index_name, _value, _index),
    do:
      raise(
        ArgumentError,
        "#{component} #{value_name} and #{index_name} must be provided together"
      )

  defp validate_loaded_identity!(
         component,
         assigns,
         item_ids,
         value_name,
         index_name,
         value,
         index
       ) do
    loaded? =
      is_integer(index) and index >= assigns.offset and
        index < assigns.offset + length(item_ids)

    if loaded? and Enum.at(item_ids, index - assigns.offset) != value do
      raise ArgumentError,
            "#{component} #{value_name} does not match the loaded item at #{index_name}"
    end
  end

  defp validate_full_collection!(component, assigns, item_ids) do
    if Map.get(assigns, :selected_index) || Map.get(assigns, :reveal_index) do
      raise ArgumentError,
            "#{component} controlled indexes require a source-backed collection with phx-range"
    end

    validate_controlled_item!(component, :selected, Map.get(assigns, :selected), item_ids)
    validate_controlled_item!(component, :reveal, Map.get(assigns, :reveal), item_ids)
  end

  defp validate_controlled_item!(_component, _name, nil, _item_ids), do: :ok

  defp validate_controlled_item!(component, name, value, item_ids) when is_binary(value) do
    if value in item_ids do
      :ok
    else
      raise ArgumentError, "#{component} #{name} must identify a loaded child"
    end
  end

  defp validate_controlled_item!(component, name, _value, _item_ids),
    do: raise(ArgumentError, "#{component} #{name} must identify a loaded child")

  defp validate_tree_item!(assigns) do
    validate_tree_item_id!(Map.get(assigns, :id))
    validate_tree_item_flags!(assigns.branch, assigns.expanded, assigns.disabled)
    validate_tree_item_level!(assigns.level)
    validate_tree_parent!(assigns.level, Map.get(assigns, :parent_id))
    validate_tree_expansion!(assigns.branch, assigns.expanded)
    validate_tree_set_position!(Map.get(assigns, :position), Map.get(assigns, :set_size))
  end

  defp validate_tree_item_id!(id) when is_binary(id) and id != "", do: :ok

  defp validate_tree_item_id!(_id),
    do: raise(ArgumentError, "ui_tree_item requires a non-empty string id")

  defp validate_tree_item_flags!(branch, expanded, disabled)
       when is_boolean(branch) and is_boolean(expanded) and is_boolean(disabled),
       do: :ok

  defp validate_tree_item_flags!(_branch, _expanded, _disabled),
    do: raise(ArgumentError, "ui_tree_item branch, expanded, and disabled must be booleans")

  defp validate_tree_item_level!(level) when is_integer(level) and level > 0, do: :ok

  defp validate_tree_item_level!(_level),
    do: raise(ArgumentError, "ui_tree_item level must be a positive integer")

  defp validate_tree_parent!(1, nil), do: :ok

  defp validate_tree_parent!(_level, parent_id) when is_binary(parent_id) and parent_id != "",
    do: :ok

  defp validate_tree_parent!(level, nil) when level > 1,
    do: raise(ArgumentError, "ui_tree_item nested items require a non-empty parent_id")

  defp validate_tree_parent!(_level, _parent_id),
    do: raise(ArgumentError, "ui_tree_item parent_id must be a non-empty string")

  defp validate_tree_expansion!(false, true),
    do: raise(ArgumentError, "ui_tree_item leaves cannot be expanded")

  defp validate_tree_expansion!(_branch, _expanded), do: :ok

  defp validate_tree_set_position!(nil, nil), do: :ok

  defp validate_tree_set_position!(position, set_size)
       when is_integer(position) and is_integer(set_size) and position > 0 and
              position <= set_size,
       do: :ok

  defp validate_tree_set_position!(_position, _set_size),
    do: raise(ArgumentError, "ui_tree_item position and set_size must be valid one-based peers")

  defp normalize_attr_key(assigns, key) do
    case Map.pop(assigns, Atom.to_string(key)) do
      {nil, assigns} -> assigns
      {value, assigns} -> Map.put_new(assigns, key, value)
    end
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
      Schema.apply_defaults(assigns, :ui_slider)
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
