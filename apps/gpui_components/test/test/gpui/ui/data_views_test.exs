defmodule GPUI.UI.DataViewsTest do
  use ExUnit.Case, async: true

  alias GPUI.Element
  alias GPUI.UI

  test "builds themed shell components with bounded contracts" do
    item = UI.sidebar_item(%{id: "button", label: "Button", active: true, "phx-click": "show"})
    menu = UI.sidebar_menu(%{id: "components-menu", children: [item]})
    group = UI.sidebar_group(%{id: "components", label: "Components", children: [menu]})

    assert %Element{type: :ui_sidebar, attrs: sidebar_attrs, children: [^group]} =
             UI.sidebar(%{id: "navigation", collapsible: "none", children: [group]})

    assert sidebar_attrs[:side] == "left"
    assert sidebar_attrs[:collapsed] == false
    assert sidebar_attrs[:collapsible] == "none"

    left = UI.status_item(%{id: "left", side: "left", children: ["Ready"]})
    right = UI.status_item(%{id: "right", side: "right", children: ["Elixir"]})

    assert %Element{type: :ui_status_bar, children: [^left, ^right]} =
             UI.status_bar(%{id: "status", children: [left, right]})

    assert %Element{type: :ui_separator, attrs: separator_attrs} =
             UI.separator(%{id: "divider", orientation: "vertical"})

    assert separator_attrs[:orientation] == "vertical"
    assert separator_attrs[:dashed] == false
  end

  test "rejects invalid shell component values" do
    assert_raise ArgumentError, fn ->
      UI.sidebar(%{id: "navigation", collapsible: "sometimes", children: []})
    end

    assert_raise ArgumentError, fn ->
      UI.status_item(%{id: "status", side: "edge", children: []})
    end
  end

  test "builds a neutral external-path drop target" do
    child = %Element{type: :text, children: ["Drop files"]}

    assert %Element{
             type: :ui_drop_target,
             attrs: attrs,
             children: [^child]
           } =
             UI.drop_target(%{
               id: "drop-zone",
               children: [child],
               "phx-drag-enter": "entered",
               "phx-drag-move": "moved",
               "phx-drag-leave": "left",
               "phx-drop": "dropped"
             })

    assert attrs[:id] == "drop-zone"
    assert attrs[:"phx-drag-enter"] == "entered"
    assert attrs[:"phx-drag-move"] == "moved"
    assert attrs[:"phx-drag-leave"] == "left"
    assert attrs[:"phx-drop"] == "dropped"
  end

  test "adds bounded clipboard reads to an ordinary button" do
    assert %Element{type: :ui_button, attrs: attrs} =
             UI.button(%{
               id: "paste",
               label: "Paste",
               "phx-clipboard-read": "clipboard_read"
             })

    assert attrs[:label] == "Paste"
    assert attrs[:"phx-clipboard-read"] == "clipboard_read"
  end

  test "builds selectable rich text from bounded neutral shaping runs" do
    alias GPUI.Text.{Position, Range, RichRun}

    bold =
      RichRun.new(
        Range.new(Position.new(0, 0), Position.new(0, 5)),
        font_weight: :bold,
        color: 0xF8FAFC
      )

    link =
      RichRun.new(
        Range.new(Position.new(1, 0), Position.new(1, 6)),
        underline: 0x60A5FA,
        link: "https://example.test"
      )

    assert %Element{type: :ui_rich_text, attrs: attrs, children: []} =
             UI.rich_text(%{
               id: "message-body",
               label: "Message",
               text: "Hello\nElixir",
               runs: [bold, link],
               "phx-link": "open_link"
             })

    assert attrs[:text] == "Hello\nElixir"
    assert attrs[:runs] == [bold, link]
    assert attrs[:selectable] == true
    assert attrs[:"phx-link"] == "open_link"

    assert %{
             runs: [
               %{font_weight: "bold", font_style: nil},
               %{font_weight: nil, underline_style: nil}
             ]
           } =
             %Element{type: :ui_rich_text, attrs: attrs, children: []}
             |> GPUI.Element.to_payload()
             |> Map.fetch!(:attrs)
  end

  test "validates rich text UTF-16 runs and link events" do
    alias GPUI.Text.{Position, Range, RichRun}

    run = fn start_position, end_position, opts ->
      RichRun.new(Range.new(start_position, end_position), opts)
    end

    assert %Element{} =
             UI.rich_text(%{
               id: "unicode",
               label: "Unicode",
               text: "A😀B",
               runs: [run.(Position.new(0, 1), Position.new(0, 3), color: 0xFFFFFF)]
             })

    assert_raise ArgumentError, ~r/within text UTF-16 bounds/, fn ->
      UI.rich_text(%{
        id: "unicode",
        label: "Unicode",
        text: "A😀B",
        runs: [run.(Position.new(0, 2), Position.new(0, 5), color: 0xFFFFFF)]
      })
    end

    assert_raise ArgumentError, ~r/non-empty forward ranges/, fn ->
      UI.rich_text(%{
        id: "empty",
        label: "Empty",
        text: "value",
        runs: [run.(Position.new(0, 1), Position.new(0, 1), color: 0xFFFFFF)]
      })
    end

    assert_raise ArgumentError, ~r/sorted and non-overlapping/, fn ->
      UI.rich_text(%{
        id: "overlap",
        label: "Overlap",
        text: "abcdef",
        runs: [
          run.(Position.new(0, 0), Position.new(0, 4), color: 0xFFFFFF),
          run.(Position.new(0, 3), Position.new(0, 5), font_weight: :bold)
        ]
      })
    end

    assert_raise ArgumentError, ~r/requires phx-link/, fn ->
      UI.rich_text(%{
        id: "link",
        label: "Link",
        text: "open",
        runs: [
          run.(Position.new(0, 0), Position.new(0, 4), link: "https://example.test")
        ]
      })
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
