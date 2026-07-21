defmodule GPUI.UI do
  @moduledoc """
  Namespaced builders for native GPUI controls, collection primitives, and
  renderer-independent UI composition.

  Components are controlled by Elixir assigns and require a stable `:id` so
  native focus, animation, and interaction state survives rerenders. Builders
  reject unsupported options and validate schema-backed attribute and event
  types before snapshots reach a display. Editable controlled components
  require `phx-change`; invalid contracts raise `ArgumentError` with the
  component, attribute, expectation, and received value.
  """

  alias GPUI.Element
  alias GPUI.Schema
  alias GPUI.UI.CollectionValidation

  require Schema

  @max_file_bytes 100 * 1_024 * 1_024

  @type select_option ::
          String.t()
          | {String.t(), String.t()}
          | %{required(:label) => String.t(), required(:value) => String.t()}

  @type radio_option ::
          select_option()
          | %{
              required(:label) => String.t(),
              required(:value) => String.t(),
              optional(:disabled) => boolean()
            }

  Schema.define_component_option_types(
    button_options: :ui_button,
    progress_options: :ui_progress,
    file_picker_options: :ui_file_picker,
    copy_button_options: :ui_copy_button,
    checkbox_options: :ui_checkbox,
    input_options: :ui_input,
    select_options: :ui_select,
    combobox_options: :ui_combobox,
    switch_options: :ui_switch,
    radio_group_options: :ui_radio_group,
    accordion_options: :ui_accordion,
    accordion_item_options: :ui_accordion_item,
    virtual_list_options: :ui_virtual_list,
    virtual_list_item_options: :ui_virtual_list_item,
    data_table_options: :ui_data_table,
    table_column_options: :ui_table_column,
    table_row_options: :ui_table_row,
    tree_options: :ui_tree,
    tree_item_options: :ui_tree_item,
    code_viewer_options: :ui_code_viewer,
    code_line_options: :ui_code_line,
    tabs_options: :ui_tabs,
    slider_options: :ui_slider
  )

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

  @doc """
  Builds a native button.

  A non-empty `label` provides the native accessibility name; child content may
  customize the visual body. `phx-click` receives activation;
  `variant`, `size`, and boolean state attributes use the schema documented in
  the components guide.

  #{Schema.component_options_doc(:ui_button)}
  """
  @spec button(button_options()) :: Element.t()
  def button(assigns), do: component(:ui_button, assigns)

  @doc """
  Builds an accessible controlled progress indicator.

  `value` defaults to zero, `max` defaults to 100, and `indeterminate` enables
  native loading animation while preserving the textual accessibility label.

  #{Schema.component_options_doc(:ui_progress)}
  """
  @spec progress(progress_options()) :: Element.t()
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

  #{Schema.component_options_doc(:ui_file_picker)}
  """
  @spec file_picker(file_picker_options()) :: Element.t()
  def file_picker(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_file_picker)

    validate_non_empty_label!(:ui_file_picker, Map.get(assigns, :label))

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

  #{Schema.component_options_doc(:ui_copy_button)}
  """
  @spec copy_button(copy_button_options()) :: Element.t()
  def copy_button(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_copy_button)
    validate_non_empty_label!(:ui_copy_button, Map.get(assigns, :label))

    unless is_binary(Map.get(assigns, :text)) do
      raise ArgumentError, "ui_copy_button requires string text"
    end

    component(:ui_copy_button, assigns)
  end

  @doc """
  Builds a labeled controlled checkbox using boolean `checked` and required `phx-change`.

  #{Schema.component_options_doc(:ui_checkbox)}
  """
  @spec checkbox(checkbox_options()) :: Element.t()
  def checkbox(assigns), do: component(:ui_checkbox, assigns)

  @doc """
  Builds a renderer-independent field containing one control, its visible label,
  and optional help or error feedback.

  Error feedback replaces help text and is prefixed with `Error:`. Set
  `required: true` to mark the visible label; validation and error state remain
  controlled by the owning view.
  """
  @spec field(map()) :: Element.t()
  defdelegate field(assigns), to: GPUI.UI.Form

  @doc """
  Builds a persistent labeled controlled string input using `value` and required `phx-change`.

  `phx-submit` optionally receives Enter activation with the current value.
  Increment `focus_request` to request native focus after validation or another
  application-owned transition.

  #{Schema.component_options_doc(:ui_input)}
  """
  @spec input(input_options()) :: Element.t()
  def input(assigns), do: component(:ui_input, assigns)

  @doc """
  Builds a persistent native GPUI Component select.

  A non-empty `label` names the control for assistive technology. Options may be
  strings, `{label, value}` tuples, or maps with string `:label` and `:value`
  fields.

  #{Schema.component_options_doc(:ui_select)}
  """
  @spec select(select_options()) :: Element.t()
  def select(assigns), do: component(:ui_select, normalize_options_assigns!(:ui_select, assigns))

  @doc """
  Builds a persistent searchable GPUI Component combobox.

  A non-empty `label` names the searchable control. Selection changes use
  `phx-change`; search text changes use `phx-search`. Options use the same
  format as `select/1`.

  #{Schema.component_options_doc(:ui_combobox)}
  """
  @spec combobox(combobox_options()) :: Element.t()
  def combobox(assigns),
    do: component(:ui_combobox, normalize_options_assigns!(:ui_combobox, assigns))

  @doc """
  Builds a controlled boolean switch.

  A non-empty `label` provides both the visible and native accessibility name;
  `phx-change` owns changes to boolean `checked` state.

  #{Schema.component_options_doc(:ui_switch)}
  """
  @spec switch(switch_options()) :: Element.t()
  def switch(assigns) when is_map(assigns) do
    validate_non_empty_label!(:ui_switch, Map.get(assigns, :label))
    component(:ui_switch, assigns)
  end

  @doc """
  Builds a controlled GPUI Component radio group.

  A non-empty `label` names the radio group for assistive technology. Options
  accept the same forms as `select/1`; maps may additionally set `disabled: true`.

  #{Schema.component_options_doc(:ui_radio_group)}
  """
  @spec radio_group(radio_group_options()) :: Element.t()
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

    validate_non_empty_label!(:ui_radio_group, Map.get(assigns, :label))
    component(:ui_radio_group, Map.put(assigns, :options, options))
  end

  def radio_group(_assigns),
    do: raise(ArgumentError, "ui_radio_group requires an options list")

  defp validate_non_empty_label!(_component, label) when is_binary(label) and label != "", do: :ok

  defp validate_non_empty_label!(component, _label),
    do: raise(ArgumentError, "#{component} requires a non-empty string label")

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

  #{Schema.component_options_doc(:ui_accordion)}
  """
  @spec accordion(accordion_options()) :: Element.t()
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

  @doc """
  Builds an item for `accordion/1`.

  #{Schema.component_options_doc(:ui_accordion_item)}
  """
  @spec accordion_item(accordion_item_options()) :: Element.t()
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

  #{Schema.component_options_doc(:ui_virtual_list)}
  """
  @spec virtual_list(virtual_list_options()) :: Element.t()
  def virtual_list(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:total_count, length(children))
      |> Schema.apply_defaults(:ui_virtual_list)

    item_ids =
      CollectionValidation.collection_item_ids!(
        :ui_virtual_list,
        :ui_virtual_list_item,
        children
      )

    CollectionValidation.validate_virtual_collection!(:ui_virtual_list, assigns, item_ids)

    component(:ui_virtual_list, assigns)
  end

  @doc """
  Builds a stable row for `virtual_list/1`.

  #{Schema.component_options_doc(:ui_virtual_list_item)}
  """
  @spec virtual_list_item(virtual_list_item_options()) :: Element.t()
  def virtual_list_item(assigns) when is_map(assigns),
    do: component(:ui_virtual_list_item, Schema.apply_defaults(assigns, :ui_virtual_list_item))

  @doc """
  Builds an accessible source-backed data grid with fixed column definitions.

  `table_column/1` children define stable columns and must precede `table_row/1`
  children. Rows use the same controlled selection, reveal, overscan, and
  exclusive `phx-range` contract as `virtual_list/1`. `phx-sort` receives a
  sortable column ID, while `phx-cell-change` receives `[row_id, column_id]`.

  #{Schema.component_options_doc(:ui_data_table)}
  """
  @spec data_table(data_table_options()) :: Element.t()
  def data_table(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])
    {columns, rows} = CollectionValidation.table_children!(children)

    assigns =
      assigns
      |> Map.put_new(:total_count, length(rows))
      |> Schema.apply_defaults(:ui_data_table)

    column_ids = Enum.map(columns, &CollectionValidation.element_id!/1)
    row_ids = Enum.map(rows, &CollectionValidation.element_id!/1)

    CollectionValidation.validate_table_columns!(columns, column_ids)
    CollectionValidation.validate_table_rows!(rows, length(columns))
    CollectionValidation.validate_virtual_collection!(:ui_data_table, assigns, row_ids)
    CollectionValidation.validate_item_height!(:ui_data_table, assigns.header_height)
    CollectionValidation.validate_table_selection!(assigns, column_ids)
    CollectionValidation.validate_table_sort!(assigns, columns, column_ids)

    component(:ui_data_table, assigns)
  end

  @doc """
  Builds one fixed column definition for `data_table/1`.

  #{Schema.component_options_doc(:ui_table_column)}
  """
  @spec table_column(table_column_options()) :: Element.t()
  def table_column(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_table_column)
    validate_non_empty_label!(:ui_table_column, assigns.label)

    unless is_number(assigns.width) and assigns.width >= 40 and assigns.width <= 2_000 do
      raise ArgumentError, "ui_table_column width must be between 40 and 2000"
    end

    component(:ui_table_column, assigns)
  end

  @doc """
  Builds one stable, uniform-height row for `data_table/1`.

  #{Schema.component_options_doc(:ui_table_row)}
  """
  @spec table_row(table_row_options()) :: Element.t()
  def table_row(assigns) when is_map(assigns),
    do: component(:ui_table_row, Schema.apply_defaults(assigns, :ui_table_row))

  @doc """
  Builds an accessible source-backed tree.

  `phx-change` receives selection and `phx-toggle` receives the stable ID whose
  expansion should change. Source-backed ranges follow the same exclusive
  `phx-range` contract as `virtual_list/1`.

  #{Schema.component_options_doc(:ui_tree)}
  """
  @spec tree(tree_options()) :: Element.t()
  def tree(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:total_count, length(children))
      |> Schema.apply_defaults(:ui_tree)

    item_ids = CollectionValidation.collection_item_ids!(:ui_tree, :ui_tree_item, children)
    CollectionValidation.validate_virtual_collection!(:ui_tree, assigns, item_ids)
    CollectionValidation.validate_event!(:ui_tree, assigns, :"phx-change")
    CollectionValidation.validate_event!(:ui_tree, assigns, :"phx-toggle")

    component(:ui_tree, assigns)
  end

  @doc """
  Builds one accessible row for `tree/1`.

  #{Schema.component_options_doc(:ui_tree_item)}
  """
  @spec tree_item(tree_item_options()) :: Element.t()
  def tree_item(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_tree_item)

    CollectionValidation.validate_tree_item!(assigns)
    component(:ui_tree_item, assigns)
  end

  @doc """
  Builds a source-backed monospaced code or unified-diff viewer.

  Lines are uniform-height `code_line/1` children. The viewer shares the
  selection, reveal, overscan, and exclusive `phx-range` contract used by
  `virtual_list/1`. `max_columns` preserves stable horizontal geometry for
  unloaded lines; Ctrl/Cmd+C copies the selected loaded line on the display
  machine and acknowledges `phx-copy` when configured.

  #{Schema.component_options_doc(:ui_code_viewer)}
  """
  @spec code_viewer(code_viewer_options()) :: Element.t()
  def code_viewer(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:total_count, length(children))
      |> Schema.apply_defaults(:ui_code_viewer)

    item_ids =
      CollectionValidation.collection_item_ids!(:ui_code_viewer, :ui_code_line, children)

    CollectionValidation.validate_virtual_collection!(:ui_code_viewer, assigns, item_ids)

    CollectionValidation.validate_non_negative_integer!(
      :ui_code_viewer,
      :max_columns,
      assigns.max_columns
    )

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

  @doc """
  Builds one native line for `code_viewer/1`.

  #{Schema.component_options_doc(:ui_code_line)}
  """
  @spec code_line(code_line_options()) :: Element.t()
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

  #{Schema.component_options_doc(:ui_tabs)}
  """
  @spec tabs(tabs_options()) :: Element.t()
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

  A non-empty `label` names the slider's native accessibility group.
  `phx-change` is emitted continuously during pointer interaction and
  `phx-release` is emitted once interaction finishes.

  #{Schema.component_options_doc(:ui_slider)}
  """
  @spec slider(slider_options()) :: Element.t()
  def slider(assigns) when is_map(assigns) do
    assigns =
      Schema.apply_defaults(assigns, :ui_slider)
      |> normalize_slider_numbers!()

    validate_slider!(assigns)
    validate_non_empty_label!(:ui_slider, Map.get(assigns, :label))
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
    assigns = Schema.validate_component_assigns!(assigns, type)

    %Element{
      type: type,
      attrs: assigns |> Map.delete(:children) |> Map.to_list(),
      children: Map.get(assigns, :children, [])
    }
  end

  defp component(type, assigns) do
    id = if is_map(assigns), do: Map.get(assigns, :id), else: nil

    raise ArgumentError,
          "#{public_component_name(type)} requires :id to be a non-empty string; " <>
            "got: #{inspect(id)}"
  end

  defp public_component_name(type) do
    name = type |> Atom.to_string() |> String.trim_leading("ui_")
    "GPUI.UI.#{name}/1"
  end
end
