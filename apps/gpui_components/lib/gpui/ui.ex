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
  alias GPUI.Components.Schema, as: ComponentsSchema
  alias GPUI.UI.CollectionValidation

  require ComponentsSchema

  @max_file_bytes 25 * 1_024 * 1_024

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

  ComponentsSchema.define_component_option_types(
    button_options: :ui_button,
    edge_fade_options: :ui_edge_fade,
    frost_options: :ui_frost,
    paint_options: :ui_paint,
    progress_options: :ui_progress,
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
    virtual_collection_options: :ui_virtual_collection,
    virtual_item_options: :ui_virtual_item,
    drop_target_options: :ui_drop_target,
    rich_text_options: :ui_rich_text,
    data_table_options: :ui_data_table,
    table_column_options: :ui_table_column,
    table_row_options: :ui_table_row,
    tree_options: :ui_tree,
    tree_item_options: :ui_tree_item,
    code_viewer_options: :ui_code_viewer,
    code_line_options: :ui_code_line,
    sidebar_options: :ui_sidebar,
    sidebar_header_options: :ui_sidebar_header,
    sidebar_group_options: :ui_sidebar_group,
    sidebar_menu_options: :ui_sidebar_menu,
    sidebar_item_options: :ui_sidebar_item,
    status_bar_options: :ui_status_bar,
    status_item_options: :ui_status_item,
    separator_options: :ui_separator,
    tabs_options: :ui_tabs,
    slider_options: :ui_slider,
    split_options: :ui_split
  )

  @type file_read_value ::
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

  `phx-clipboard-write` writes bounded `clipboard_text` to the display-side
  clipboard on activation. `phx-clipboard-read` reads bounded display-side text
  and emits it as `GPUI.Transfer.Payload`. When clipboard and click events are
  combined, the clipboard operation is performed first.

  `phx-file-read` opens a display-side file picker, reads one bounded file, and
  emits `file_read_value/0`. `file_max_bytes` defaults to 10 MiB and may not
  exceed 25 MiB. Clipboard operations run before file reads, and file reads run
  before an ordinary click event.

  #{ComponentsSchema.component_options_doc(:ui_button)}
  """
  @spec button(button_options()) :: Element.t()
  def button(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> normalize_attr_key(:"phx-clipboard-read")
      |> normalize_attr_key(:"phx-clipboard-write")

    assigns = ComponentsSchema.apply_defaults(assigns, :ui_button)

    case Map.get(assigns, :clipboard_text) do
      nil ->
        :ok

      text when is_binary(text) and byte_size(text) <= 1_048_576 ->
        unless String.valid?(text),
          do: raise(ArgumentError, "GPUI.UI.button/1 clipboard_text must be valid UTF-8")

      _invalid ->
        raise ArgumentError,
              "GPUI.UI.button/1 clipboard_text must be UTF-8 text no larger than 1 MiB"
    end

    unless is_integer(Map.get(assigns, :file_max_bytes, 10_485_760)) and
             Map.get(assigns, :file_max_bytes, 10_485_760) in 1..@max_file_bytes do
      raise ArgumentError,
            "GPUI.UI.button/1 file_max_bytes must be between 1 and #{@max_file_bytes}"
    end

    component(:ui_button, assigns)
  end

  @doc """
  Builds a neutral bounded edge-fade overlay around arbitrary child content.

  `edges` is a unique subset of `:top`, `:right`, `:bottom`, and `:left`.
  `size` is bounded to 1–256 native pixels and `opacity` to 0–1.

  #{ComponentsSchema.component_options_doc(:ui_edge_fade)}
  """
  @spec edge_fade(edge_fade_options()) :: Element.t()
  def edge_fade(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> ComponentsSchema.apply_defaults(:ui_edge_fade)
      |> Map.update!(:edges, &Enum.map(&1, fn edge -> to_string(edge) end))

    component(:ui_edge_fade, assigns)
  end

  @doc """
  Builds a declarative frosted surface with an explicit fallback contract.

  Set `reduced_transparency: true` from application accessibility policy to
  force an opaque surface. `fallback` controls unsupported-platform behavior.

  #{ComponentsSchema.component_options_doc(:ui_frost)}
  """
  @spec frost(frost_options()) :: Element.t()
  def frost(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_frost)
    component(:ui_frost, assigns)
  end

  @doc """
  Builds a bounded serializable custom-paint display list.

  Commands are closed rectangle and line maps. The schema accepts at most 256
  commands with bounded coordinates, dimensions, stroke widths, and RGBA colors.

  #{ComponentsSchema.component_options_doc(:ui_paint)}
  """
  @spec paint(paint_options()) :: Element.t()
  def paint(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> ComponentsSchema.apply_defaults(:ui_paint)
      |> then(&ComponentsSchema.validate_component_assigns!(&1, :ui_paint))

    commands =
      Enum.map(Map.fetch!(assigns, :commands), fn command ->
        kind = command.type |> to_string()
        x = Map.get(command, :x, Map.get(command, :x1, 0))
        y = Map.get(command, :y, Map.get(command, :y1, 0))
        x2 = Map.get(command, :x2, 0)
        y2 = Map.get(command, :y2, 0)
        width = Map.get(command, :width, 0)
        height = Map.get(command, :height, 0)

        %{
          kind: kind,
          x: x,
          y: y,
          x2: x2,
          y2: y2,
          width: width,
          height: height,
          color: command.color
        }
      end)

    %Element{
      type: :ui_paint,
      attrs: assigns |> Map.put(:commands, commands) |> Map.to_list(),
      children: []
    }
  end

  @doc """
  Builds an accessible controlled progress indicator.

  `value` defaults to zero, `max` defaults to 100, and `indeterminate` enables
  native loading animation while preserving the textual accessibility label.

  #{ComponentsSchema.component_options_doc(:ui_progress)}
  """
  @spec progress(progress_options()) :: Element.t()
  def progress(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_progress)

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
  Builds a labeled controlled checkbox using boolean `checked` and required `phx-change`.

  #{ComponentsSchema.component_options_doc(:ui_checkbox)}
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

  #{ComponentsSchema.component_options_doc(:ui_input)}
  """
  @spec input(input_options()) :: Element.t()
  def input(assigns), do: component(:ui_input, assigns)

  @doc """
  Builds a persistent native GPUI Component select.

  A non-empty `label` names the control for assistive technology. Options may be
  strings, `{label, value}` tuples, or maps with string `:label` and `:value`
  fields.

  #{ComponentsSchema.component_options_doc(:ui_select)}
  """
  @spec select(select_options()) :: Element.t()
  def select(assigns), do: component(:ui_select, normalize_options_assigns!(:ui_select, assigns))

  @doc """
  Builds a persistent searchable GPUI Component combobox.

  A non-empty `label` names the searchable control. Selection changes use
  `phx-change`; search text changes use `phx-search`. Options use the same
  format as `select/1`.

  #{ComponentsSchema.component_options_doc(:ui_combobox)}
  """
  @spec combobox(combobox_options()) :: Element.t()
  def combobox(assigns),
    do: component(:ui_combobox, normalize_options_assigns!(:ui_combobox, assigns))

  @doc """
  Builds a controlled boolean switch.

  A non-empty `label` provides both the visible and native accessibility name;
  `phx-change` owns changes to boolean `checked` state.

  #{ComponentsSchema.component_options_doc(:ui_switch)}
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

  #{ComponentsSchema.component_options_doc(:ui_radio_group)}
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

  #{ComponentsSchema.component_options_doc(:ui_accordion)}
  """
  @spec accordion(accordion_options()) :: Element.t()
  def accordion(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_accordion)

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

  #{ComponentsSchema.component_options_doc(:ui_accordion_item)}
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

  #{ComponentsSchema.component_options_doc(:ui_virtual_list)}
  """
  @spec virtual_list(virtual_list_options()) :: Element.t()
  def virtual_list(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:total_count, length(children))
      |> ComponentsSchema.apply_defaults(:ui_virtual_list)

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

  #{ComponentsSchema.component_options_doc(:ui_virtual_list_item)}
  """
  @spec virtual_list_item(virtual_list_item_options()) :: Element.t()
  def virtual_list_item(assigns) when is_map(assigns),
    do:
      component(
        :ui_virtual_list_item,
        ComponentsSchema.apply_defaults(assigns, :ui_virtual_list_item)
      )

  @doc """
  Builds a variable-height virtual collection from stable `virtual_item/1` children.

  The complete logical collection remains in the renderer-independent snapshot,
  while the native display measures and renders only the visible region. Items
  may have different heights and may change height between snapshots.

  `alignment` controls the initial edge, `follow` enables native tail-following,
  and incrementing `follow_request` explicitly returns to the tail. Increment
  `reveal_request` to repeat a reveal of the same item. `phx-range`, when set,
  receives deduplicated `%{first: first, last: last}` visible ranges where
  `last` is exclusive.

  Source-backed slices are intentionally unsupported until unloaded variable
  heights have an explicit estimation contract.

  #{ComponentsSchema.component_options_doc(:ui_virtual_collection)}
  """
  @spec virtual_collection(virtual_collection_options()) :: Element.t()
  def virtual_collection(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_virtual_collection)

    item_ids =
      CollectionValidation.collection_item_ids!(
        :ui_virtual_collection,
        :ui_virtual_item,
        children
      )

    CollectionValidation.validate_variable_collection!(assigns, item_ids)
    component(:ui_virtual_collection, assigns)
  end

  @doc """
  Builds one stable, variable-height item for `virtual_collection/1`.

  IDs are renderer identity and must be non-empty UTF-8 strings no larger than
  128 bytes. Increment `revision` whenever a retained item's content can change
  its measured height; unchanged revisions preserve the native height cache.

  #{ComponentsSchema.component_options_doc(:ui_virtual_item)}
  """
  @spec virtual_item(virtual_item_options()) :: Element.t()
  def virtual_item(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_virtual_item)

    CollectionValidation.validate_non_negative_integer!(
      :ui_virtual_item,
      :revision,
      assigns.revision
    )

    component(:ui_virtual_item, assigns)
  end

  @doc """
  Builds a neutral operating-system external-path drop target.

  Paths always refer to the display machine. The renderer bounds and validates
  paths before emitting typed drag events and never reads dropped files.

  #{ComponentsSchema.component_options_doc(:ui_drop_target)}
  """
  @spec drop_target(drop_target_options()) :: Element.t()
  def drop_target(assigns) when is_map(assigns) do
    assigns =
      Enum.reduce(~w(phx-drag-enter phx-drag-move phx-drag-leave phx-drop)a, assigns, fn key,
                                                                                         attrs ->
        normalize_attr_key(attrs, key)
      end)

    assigns = ComponentsSchema.apply_defaults(assigns, :ui_drop_target)
    ComponentsSchema.validate_component_assigns!(assigns, :ui_drop_target)
    component(:ui_drop_target, assigns)
  end

  @doc """
  Builds immutable, selectable, natively shaped rich text.

  Elixir supplies plain UTF-8 `text` and bounded `GPUI.Text.RichRun` renderer
  facts. Runs use zero-based UTF-16 document positions and must be sorted,
  non-overlapping, non-empty, and within the supplied text. Unstyled gaps inherit
  the component's ordinary text style.

  Native state owns transient selection and system copy. Link runs require
  `phx-link`; activation emits the run's opaque `link` value through the ordinary
  controlled event path. This component does not parse Markdown or HTML.

  #{ComponentsSchema.component_options_doc(:ui_rich_text)}
  """
  @spec rich_text(rich_text_options()) :: Element.t()
  def rich_text(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-link")
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_rich_text)
    CollectionValidation.validate_rich_text!(assigns)
    component(:ui_rich_text, assigns)
  end

  @doc """
  Builds an accessible source-backed data grid with fixed column definitions.

  `table_column/1` children define stable columns and must precede `table_row/1`
  children. Rows use the same controlled selection, reveal, overscan, and
  exclusive `phx-range` contract as `virtual_list/1`. `phx-sort` receives a
  sortable column ID, while `phx-cell-change` receives `[row_id, column_id]`.

  #{ComponentsSchema.component_options_doc(:ui_data_table)}
  """
  @spec data_table(data_table_options()) :: Element.t()
  def data_table(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])
    {columns, rows} = CollectionValidation.table_children!(children)

    assigns =
      assigns
      |> Map.put_new(:total_count, length(rows))
      |> ComponentsSchema.apply_defaults(:ui_data_table)

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

  #{ComponentsSchema.component_options_doc(:ui_table_column)}
  """
  @spec table_column(table_column_options()) :: Element.t()
  def table_column(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_table_column)
    validate_non_empty_label!(:ui_table_column, assigns.label)

    unless is_number(assigns.width) and assigns.width >= 40 and assigns.width <= 2_000 do
      raise ArgumentError, "ui_table_column width must be between 40 and 2000"
    end

    component(:ui_table_column, assigns)
  end

  @doc """
  Builds one stable, uniform-height row for `data_table/1`.

  #{ComponentsSchema.component_options_doc(:ui_table_row)}
  """
  @spec table_row(table_row_options()) :: Element.t()
  def table_row(assigns) when is_map(assigns),
    do: component(:ui_table_row, ComponentsSchema.apply_defaults(assigns, :ui_table_row))

  @doc """
  Builds an accessible source-backed tree.

  `phx-change` receives selection and `phx-toggle` receives the stable ID whose
  expansion should change. Source-backed ranges follow the same exclusive
  `phx-range` contract as `virtual_list/1`.

  #{ComponentsSchema.component_options_doc(:ui_tree)}
  """
  @spec tree(tree_options()) :: Element.t()
  def tree(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:total_count, length(children))
      |> ComponentsSchema.apply_defaults(:ui_tree)

    item_ids = CollectionValidation.collection_item_ids!(:ui_tree, :ui_tree_item, children)
    CollectionValidation.validate_virtual_collection!(:ui_tree, assigns, item_ids)
    CollectionValidation.validate_event!(:ui_tree, assigns, :"phx-change")
    CollectionValidation.validate_event!(:ui_tree, assigns, :"phx-toggle")

    component(:ui_tree, assigns)
  end

  @doc """
  Builds one accessible row for `tree/1`.

  #{ComponentsSchema.component_options_doc(:ui_tree_item)}
  """
  @spec tree_item(tree_item_options()) :: Element.t()
  def tree_item(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_tree_item)

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

  #{ComponentsSchema.component_options_doc(:ui_code_viewer)}
  """
  @spec code_viewer(code_viewer_options()) :: Element.t()
  def code_viewer(assigns) when is_map(assigns) do
    assigns = normalize_attr_key(assigns, :"phx-range")
    children = Map.get(assigns, :children, [])

    assigns =
      assigns
      |> Map.put_new(:total_count, length(children))
      |> ComponentsSchema.apply_defaults(:ui_code_viewer)

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

  #{ComponentsSchema.component_options_doc(:ui_code_line)}
  """
  @spec code_line(code_line_options()) :: Element.t()
  def code_line(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_code_line)

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

  @doc "Builds a themed GPUI Component sidebar."
  @spec sidebar(sidebar_options()) :: Element.t()
  def sidebar(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_sidebar)
    component(:ui_sidebar, assigns)
  end

  @doc "Builds the header region of a sidebar."
  @spec sidebar_header(sidebar_header_options()) :: Element.t()
  def sidebar_header(assigns) when is_map(assigns), do: component(:ui_sidebar_header, assigns)

  @doc "Builds a labelled sidebar item group."
  @spec sidebar_group(sidebar_group_options()) :: Element.t()
  def sidebar_group(assigns) when is_map(assigns), do: component(:ui_sidebar_group, assigns)

  @doc "Builds a sidebar menu containing sidebar items."
  @spec sidebar_menu(sidebar_menu_options()) :: Element.t()
  def sidebar_menu(assigns) when is_map(assigns), do: component(:ui_sidebar_menu, assigns)

  @doc "Builds a left-aligned sidebar navigation item."
  @spec sidebar_item(sidebar_item_options()) :: Element.t()
  def sidebar_item(assigns) when is_map(assigns), do: component(:ui_sidebar_item, assigns)

  @doc "Builds a themed bottom status bar."
  @spec status_bar(status_bar_options()) :: Element.t()
  def status_bar(assigns) when is_map(assigns), do: component(:ui_status_bar, assigns)

  @doc "Places children in a named status-bar region."
  @spec status_item(status_item_options()) :: Element.t()
  def status_item(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_status_item)
    component(:ui_status_item, assigns)
  end

  @doc "Builds a horizontal or vertical themed separator."
  @spec separator(separator_options()) :: Element.t()
  def separator(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_separator)
    component(:ui_separator, assigns)
  end

  @doc """
  Builds a controlled GPUI Component tab bar.

  Options use the same label/value format as `select/1`; `value` identifies the
  selected tab and changes are emitted through `phx-change`.

  #{ComponentsSchema.component_options_doc(:ui_tabs)}
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
  Builds a persistent controlled two-pane native resizable split.

  `sizes`, `min_sizes`, and `max_sizes` are two-element pixel lists. The native
  display owns transient drag mechanics and emits the resulting sizes through
  `phx-change`; the authoritative sizes remain in Elixir assigns.

  #{ComponentsSchema.component_options_doc(:ui_split)}
  """
  @spec split(split_options()) :: Element.t()
  def split(assigns) when is_map(assigns) do
    assigns = ComponentsSchema.apply_defaults(assigns, :ui_split)
    validate_split!(assigns)
    component(:ui_split, assigns)
  end

  @doc """
  Builds a persistent controlled GPUI Component slider.

  A non-empty `label` names the slider's native accessibility group.
  `phx-change` is emitted continuously during pointer interaction and
  `phx-release` is emitted once interaction finishes.

  #{ComponentsSchema.component_options_doc(:ui_slider)}
  """
  @spec slider(slider_options()) :: Element.t()
  def slider(assigns) when is_map(assigns) do
    assigns =
      ComponentsSchema.apply_defaults(assigns, :ui_slider)
      |> normalize_slider_numbers!()

    validate_slider!(assigns)
    validate_non_empty_label!(:ui_slider, Map.get(assigns, :label))
    component(:ui_slider, assigns)
  end

  defp validate_split!(assigns) do
    validate_split_children!(Map.get(assigns, :children, []))
    validate_split_request!(assigns.resize_request)

    Enum.each(
      [:sizes, :min_sizes, :max_sizes],
      &validate_split_pair!(&1, Map.fetch!(assigns, &1))
    )

    validate_split_ranges!(assigns.sizes, assigns.min_sizes, assigns.max_sizes)
  end

  defp validate_split_children!([_first, _second]), do: :ok

  defp validate_split_children!(_children),
    do: raise(ArgumentError, "ui_split requires exactly two children")

  defp validate_split_request!(request) when is_integer(request) and request >= 0, do: :ok

  defp validate_split_request!(_request),
    do: raise(ArgumentError, "ui_split resize_request must be a non-negative integer")

  defp validate_split_pair!(_name, [first, second])
       when is_number(first) and first >= 0 and first <= 100_000 and is_number(second) and
              second >= 0 and second <= 100_000,
       do: :ok

  defp validate_split_pair!(name, _values) do
    raise ArgumentError,
          "ui_split #{name} must contain exactly two pixel values between 0 and 100000"
  end

  defp validate_split_ranges!([first, second], [first_min, second_min], [first_max, second_max])
       when first_min <= first and first <= first_max and second_min <= second and
              second <= second_max,
       do: :ok

  defp validate_split_ranges!(_sizes, _mins, _maxes),
    do: raise(ArgumentError, "ui_split sizes must be within their min_sizes and max_sizes")

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
    assigns = ComponentsSchema.validate_component_assigns!(assigns, type)

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
