defmodule GPUI.UITest do
  use ExUnit.Case, async: true

  alias GPUI.Element
  alias GPUI.UI

  test "builds progress, file picker, and clipboard controls" do
    assert %Element{type: :ui_progress, attrs: progress} =
             UI.progress(%{id: "upload", label: "Uploading", value: 25, max: 50})

    assert progress[:value] == 25
    assert progress[:max] == 50
    assert progress[:indeterminate] == false

    assert %Element{type: :ui_file_picker, attrs: picker} =
             UI.file_picker(%{:"phx-change" => "selected", id: "source", label: "Choose source"})

    assert picker[:max_bytes] == 25 * 1_024 * 1_024

    assert %Element{type: :ui_copy_button, attrs: copy} =
             UI.copy_button(%{:"phx-click" => "copied", id: "copy", label: "Copy", text: "value"})

    assert copy[:text] == "value"
  end

  test "validates progress, file picker, and clipboard values" do
    assert_raise ArgumentError, ~r/value must be between zero and max/, fn ->
      UI.progress(%{id: "upload", label: "Uploading", value: 101})
    end

    assert_raise ArgumentError, ~r/max_bytes must be between/, fn ->
      UI.file_picker(%{
        :"phx-change" => "selected",
        id: "source",
        label: "Choose",
        max_bytes: 1.5
      })
    end

    assert_raise ArgumentError, ~r/requires string text/, fn ->
      UI.copy_button(%{:"phx-click" => "copied", id: "copy", label: "Copy", text: :invalid})
    end
  end

  test "validates schema-backed component attributes before native rendering" do
    assert_raise ArgumentError, ~r/ui_button :label must be a string; got: 42/, fn ->
      UI.button(%{id: "save", label: 42})
    end

    assert_raise ArgumentError, ~r/ui_button :variant must be one of .*got: "loud"/, fn ->
      UI.button(%{id: "save", label: "Save", variant: "loud"})
    end

    assert_raise ArgumentError, ~r/ui_checkbox :checked must be a boolean; got: "yes"/, fn ->
      UI.checkbox(%{id: "remember", checked: "yes"})
    end

    assert_raise ArgumentError, ~r/ui_input :value must be a string; got: 7/, fn ->
      UI.input(%{id: "name", value: 7})
    end

    assert_raise ArgumentError, ~r/ui_button :phx-click must be a non-empty string/, fn ->
      UI.button(%{id: "save", label: "Save", "phx-click": :save})
    end
  end

  test "builds controlled virtual lists from stable uniform items" do
    first = UI.virtual_list_item(%{id: "first", children: ["First"]})
    second = UI.virtual_list_item(%{id: "second", disabled: true, children: ["Second"]})

    assert %Element{
             type: :ui_virtual_list,
             attrs: attrs,
             children: [^first, ^second]
           } =
             UI.virtual_list(%{
               id: "records",
               label: "Records",
               selected: "first",
               reveal: "first",
               item_height: 48,
               children: [first, second]
             })

    assert attrs[:selected] == "first"
    assert attrs[:reveal] == "first"
    assert attrs[:reveal_strategy] == "nearest"
    assert attrs[:total_count] == 2
    assert attrs[:offset] == 0
    assert attrs[:overscan] == 8
    assert attrs[:item_height] == 48
  end

  test "builds source-backed virtual lists from contiguous loaded slices" do
    items =
      Enum.map(51..60, fn number ->
        UI.virtual_list_item(%{id: "item-#{number}", children: ["Item #{number}"]})
      end)

    assert %Element{attrs: attrs, children: ^items} =
             UI.virtual_list(%{
               :"phx-range" => "records_range",
               id: "records",
               label: "Records",
               total_count: 100_000,
               offset: 50,
               overscan: 12,
               selected: "item-75001",
               selected_index: 75_000,
               reveal: "item-75001",
               reveal_index: 75_000,
               children: items
             })

    assert attrs[:total_count] == 100_000
    assert attrs[:offset] == 50
    assert attrs[:selected_index] == 75_000
    assert attrs[:reveal_index] == 75_000
    assert attrs[:"phx-range"] == "records_range"
  end

  test "validates source-backed virtual list ranges and controlled indexes" do
    item = UI.virtual_list_item(%{id: "item-11"})
    base = %{:"phx-range" => "range", id: "records", label: "Records", total_count: 100}

    assert_raise ArgumentError, ~r/offset must be between/, fn ->
      UI.virtual_list(Map.merge(base, %{offset: 101, children: []}))
    end

    assert_raise ArgumentError, ~r/loaded slice exceeds/, fn ->
      UI.virtual_list(Map.merge(base, %{offset: 100, children: [item]}))
    end

    assert_raise ArgumentError, ~r/selected and selected_index must be provided together/, fn ->
      UI.virtual_list(Map.merge(base, %{selected: "item-1", children: []}))
    end

    assert_raise ArgumentError, ~r/does not match the loaded item/, fn ->
      UI.virtual_list(
        Map.merge(base, %{
          offset: 10,
          selected: "item-other",
          selected_index: 10,
          children: [item]
        })
      )
    end
  end

  test "builds source-backed data tables with stable columns and rows" do
    columns = [
      UI.table_column(%{id: "name", label: "Name", width: 240, sortable: true}),
      UI.table_column(%{id: "memory", label: "Memory", width: 120, align: "right"})
    ]

    rows = [
      UI.table_row(%{id: "row-501", children: ["alpha", "1 KB"]}),
      UI.table_row(%{id: "row-502", children: ["beta", "2 KB"]})
    ]

    assert %Element{type: :ui_data_table, attrs: attrs, children: children} =
             UI.data_table(%{
               :"phx-change" => "row_selected",
               :"phx-cell-change" => "cell_selected",
               :"phx-range" => "table_range",
               :"phx-sort" => "table_sorted",
               id: "records",
               label: "Records",
               total_count: 100_000,
               offset: 500,
               selected: "row-501",
               selected_index: 500,
               selected_column: "memory",
               reveal: "row-501",
               reveal_index: 500,
               sort_column: "name",
               sort_direction: "ascending",
               children: columns ++ rows
             })

    assert children == columns ++ rows
    assert attrs[:total_count] == 100_000
    assert attrs[:offset] == 500
    assert attrs[:selected_column] == "memory"
    assert attrs[:sort_direction] == "ascending"
    assert attrs[:item_height] == 44.0
    assert attrs[:header_height] == 40.0
  end

  test "validates data table structure, columns, rows, and sorting" do
    column = UI.table_column(%{id: "name", label: "Name"})
    row = UI.table_row(%{id: "row-1", children: ["alpha"]})

    assert_raise ArgumentError, ~r/table_column children followed by table_row/, fn ->
      UI.data_table(%{id: "records", label: "Records", children: [row, column]})
    end

    assert_raise ArgumentError, ~r/one cell child per column/, fn ->
      UI.data_table(%{id: "records", label: "Records", children: [column, %{row | children: []}]})
    end

    assert_raise ArgumentError, ~r/requires phx-sort/, fn ->
      UI.data_table(%{
        id: "records",
        label: "Records",
        children: [UI.table_column(%{id: "name", label: "Name", sortable: true}), row]
      })
    end

    assert_raise ArgumentError, ~r/sort_column must identify a sortable/, fn ->
      UI.data_table(%{
        :"phx-sort" => "sorted",
        id: "records",
        label: "Records",
        sort_column: "name",
        sort_direction: "ascending",
        children: [column, row]
      })
    end
  end

  test "builds accessible source-backed trees with structural metadata" do
    branch =
      UI.tree_item(%{
        id: "lib",
        level: 1,
        branch: true,
        expanded: true,
        position: 1,
        set_size: 1,
        children: ["lib"]
      })

    child =
      UI.tree_item(%{
        id: "lib/runtime.ex",
        parent_id: "lib",
        level: 2,
        position: 1,
        set_size: 1,
        children: ["runtime.ex"]
      })

    assert %Element{type: :ui_tree, attrs: attrs, children: [^branch, ^child]} =
             UI.tree(%{
               :"phx-change" => "selected",
               :"phx-toggle" => "toggled",
               :"phx-range" => "range",
               id: "files",
               label: "Repository files",
               total_count: 10_000,
               selected: "lib/runtime.ex",
               selected_index: 1,
               reveal: "lib/runtime.ex",
               reveal_index: 1,
               children: [branch, child]
             })

    assert attrs[:total_count] == 10_000
    assert attrs[:selected_index] == 1
    assert attrs[:overscan] == 8

    assert %Element{attrs: root_attrs} = UI.tree_item(%{id: "root", parent_id: nil})
    assert root_attrs[:parent_id] == nil
  end

  test "validates tree hierarchy and accessibility positions" do
    assert_raise ArgumentError, ~r/nested items require/, fn ->
      UI.tree_item(%{id: "child", level: 2})
    end

    assert_raise ArgumentError, ~r/leaves cannot be expanded/, fn ->
      UI.tree_item(%{id: "leaf", expanded: true})
    end

    assert_raise ArgumentError, ~r/position and set_size/, fn ->
      UI.tree_item(%{id: "leaf", position: 2, set_size: 1})
    end

    assert_raise ArgumentError, ~r/requires phx-toggle/, fn ->
      UI.tree(%{
        :"phx-change" => "selected",
        id: "files",
        label: "Files",
        children: [UI.tree_item(%{id: "file"})]
      })
    end
  end

  test "builds source-backed code and diff viewers" do
    lines = [
      UI.code_line(%{id: "line-501", number: 501, text: "def render(assigns) do"}),
      UI.code_line(%{id: "line-502", number: 502, text: "+  :ok", kind: "addition"})
    ]

    assert %Element{type: :ui_code_viewer, attrs: attrs, children: ^lines} =
             UI.code_viewer(%{
               :"phx-change" => "line_selected",
               :"phx-range" => "code_range",
               :"phx-copy" => "line_copied",
               id: "source",
               label: "Source code",
               mode: "diff",
               total_count: 100_000,
               offset: 500,
               max_columns: 240,
               selected: "line-501",
               selected_index: 500,
               reveal: "line-501",
               reveal_index: 500,
               children: lines
             })

    assert attrs[:mode] == "diff"
    assert attrs[:max_columns] == 240
    assert attrs[:tab_width] == 4
    assert attrs[:show_line_numbers]
    assert attrs[:selected_index] == 500
    assert attrs[:reveal_index] == 500

    assert %Element{attrs: log_line_attrs} =
             UI.code_line(%{id: "log-1", text: "queue depth high", kind: "warning"})

    assert log_line_attrs[:kind] == "warning"
  end

  test "validates code viewer structure and line metadata" do
    line = UI.code_line(%{id: "line-1", number: 1, text: "hello"})

    assert_raise ArgumentError, ~r/only accepts .*code_line/, fn ->
      UI.code_viewer(%{id: "code", label: "Code", children: [UI.tree_item(%{id: "bad"})]})
    end

    assert_raise ArgumentError, ~r/tab_width must be between/, fn ->
      UI.code_viewer(%{id: "code", label: "Code", tab_width: 32, children: [line]})
    end

    assert_raise ArgumentError, ~r/max_columns must be at most/, fn ->
      UI.code_viewer(%{id: "code", label: "Code", max_columns: 20_001, children: [line]})
    end

    assert_raise ArgumentError, ~r/kind must be/, fn ->
      UI.code_line(%{id: "line", text: "bad", kind: "fatal"})
    end
  end

  test "validates virtual list structure and controlled IDs" do
    item = UI.virtual_list_item(%{id: "first"})

    assert_raise ArgumentError, ~r/non-empty string label/, fn ->
      UI.virtual_list(%{id: "records", children: [item]})
    end

    assert_raise ArgumentError, ~r/item IDs must be unique/, fn ->
      UI.virtual_list(%{id: "records", label: "Records", children: [item, item]})
    end

    assert_raise ArgumentError, ~r/selected must identify/, fn ->
      UI.virtual_list(%{
        id: "records",
        label: "Records",
        selected: "missing",
        children: [item]
      })
    end

    assert_raise ArgumentError, ~r/item_height must be greater than zero/, fn ->
      UI.virtual_list(%{id: "records", label: "Records", item_height: 0, children: [item]})
    end

    assert_raise ArgumentError, ~r/only accepts .*virtual_list_item/, fn ->
      UI.virtual_list(%{
        id: "records",
        label: "Records",
        children: [%Element{type: :div}]
      })
    end
  end
end
