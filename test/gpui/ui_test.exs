defmodule GPUI.UITest do
  use ExUnit.Case, async: true

  alias GPUI.Element
  alias GPUI.UI

  test "builds progress, file-read, and clipboard controls" do
    assert %Element{type: :ui_progress, attrs: progress} =
             UI.progress(%{id: "upload", label: "Uploading", value: 25, max: 50})

    assert progress[:value] == 25
    assert progress[:max] == 50
    assert progress[:indeterminate] == false

    assert %Element{type: :ui_button, attrs: picker} =
             UI.button(%{
               :"phx-file-read" => "selected",
               id: "source",
               label: "Choose source"
             })

    assert picker[:file_max_bytes] == 10 * 1_024 * 1_024

    assert %Element{type: :ui_button, attrs: copy} =
             UI.button(%{
               :"phx-clipboard-write" => "copied",
               id: "copy",
               label: "Copy",
               clipboard_text: "value"
             })

    assert copy[:clipboard_text] == "value"
  end

  test "builds bounded edge fades with closed edge values" do
    fade =
      UI.edge_fade(%{
        id: "feed-fades",
        edges: [:top, :bottom],
        size: 32,
        opacity: 0.75,
        children: ["content"]
      })

    assert %Element{type: :ui_edge_fade, attrs: attrs, children: ["content"]} = fade
    assert attrs[:edges] == ["top", "bottom"]
    assert attrs[:size] == 32
    assert attrs[:opacity] == 0.75

    assert_raise ArgumentError, ~r/unique list drawn from/, fn ->
      UI.edge_fade(%{id: "bad-edges", edges: [:top, :top]})
    end

    assert_raise ArgumentError, ~r/number from 1 through 256/, fn ->
      UI.edge_fade(%{id: "bad-size", size: 257})
    end

    assert_raise ArgumentError, ~r/number from zero through one/, fn ->
      UI.edge_fade(%{id: "bad-opacity", opacity: 1.1})
    end
  end

  test "builds frost with explicit accessibility and fallback policy" do
    assert %Element{type: :ui_frost, attrs: attrs, children: ["content"]} =
             UI.frost(%{id: "inspector", children: ["content"]})

    assert attrs[:fallback] == "solid"
    assert attrs[:opacity] == 0.82
    assert attrs[:reduced_transparency] == false

    assert %Element{attrs: reduced} =
             UI.frost(%{
               id: "reduced",
               fallback: "translucent",
               opacity: 0.5,
               reduced_transparency: true
             })

    assert reduced[:fallback] == "translucent"
    assert reduced[:reduced_transparency] == true

    assert_raise ArgumentError, ~r/fallback must be one of/, fn ->
      UI.frost(%{id: "bad-fallback", fallback: "blur-or-crash"})
    end

    assert_raise ArgumentError, ~r/number from zero through one/, fn ->
      UI.frost(%{id: "bad-opacity", opacity: -0.1})
    end
  end

  test "validates progress, file-read, and clipboard values" do
    assert_raise ArgumentError, ~r/value must be between zero and max/, fn ->
      UI.progress(%{id: "upload", label: "Uploading", value: 101})
    end

    assert_raise ArgumentError, ~r/file_max_bytes must be between/, fn ->
      UI.button(%{
        :"phx-file-read" => "selected",
        id: "source",
        label: "Choose",
        file_max_bytes: 1.5
      })
    end

    assert_raise ArgumentError, ~r/clipboard_text/, fn ->
      UI.button(%{
        :"phx-clipboard-write" => "copied",
        id: "copy",
        label: "Copy",
        clipboard_text: :invalid
      })
    end

    assert_raise ArgumentError, ~r/no larger than 1 MiB/, fn ->
      UI.button(%{
        :"phx-clipboard-write" => "copied",
        id: "copy",
        label: "Copy",
        clipboard_text: :binary.copy("x", 1_048_577)
      })
    end
  end

  test "validates schema-backed component attributes before native rendering" do
    assert_raise ArgumentError, ~r/ui_button :label must be a non-empty string; got: 42/, fn ->
      UI.button(%{id: "save", label: 42})
    end

    assert_raise ArgumentError, ~r/ui_button :variant must be one of .*got: "loud"/, fn ->
      UI.button(%{id: "save", label: "Save", variant: "loud"})
    end

    assert_raise ArgumentError, ~r/ui_checkbox :checked must be a boolean; got: "yes"/, fn ->
      UI.checkbox(%{id: "remember", label: "Remember me", checked: "yes"})
    end

    assert_raise ArgumentError, ~r/ui_input :value must be a string; got: 7/, fn ->
      UI.input(%{id: "name", label: "Name", value: 7})
    end

    assert_raise ArgumentError, ~r/ui_input :focus_request must be a non-negative integer/, fn ->
      UI.input(%{
        id: "name",
        label: "Name",
        focus_request: -1,
        "phx-change": "name_changed"
      })
    end

    assert_raise ArgumentError, ~r/ui_button :phx-click must be a non-empty string/, fn ->
      UI.button(%{id: "save", label: "Save", "phx-click": :save})
    end

    assert_raise ArgumentError, ~r/ui_button received unsupported attributes: :disabeld/, fn ->
      UI.button(%{id: "save", label: "Save", disabeld: true})
    end
  end

  test "requires semantic labels for interactive controls" do
    assert_raise ArgumentError, ~r/ui_button :label must be a non-empty string/, fn ->
      UI.button(%{id: "save"})
    end

    assert_raise ArgumentError, ~r/ui_checkbox :label must be a non-empty string/, fn ->
      UI.checkbox(%{id: "remember", "phx-change": "remember_changed"})
    end

    assert_raise ArgumentError, ~r/ui_input :label must be a non-empty string/, fn ->
      UI.input(%{id: "name", "phx-change": "name_changed"})
    end

    assert_raise ArgumentError, ~r/ui_select :label must be a non-empty string/, fn ->
      UI.select(%{id: "language", options: ["Elixir"], "phx-change": "language_changed"})
    end

    assert_raise ArgumentError, ~r/ui_combobox :label must be a non-empty string/, fn ->
      UI.combobox(%{id: "framework", options: ["Phoenix"], "phx-change": "framework_changed"})
    end

    assert_raise ArgumentError, ~r/ui_switch requires a non-empty string label/, fn ->
      UI.switch(%{id: "notifications", checked: true, "phx-change": "notifications_changed"})
    end

    assert_raise ArgumentError, ~r/ui_radio_group requires a non-empty string label/, fn ->
      UI.radio_group(%{
        id: "plan",
        value: "free",
        options: [{"Free", "free"}],
        "phx-change": "plan_changed"
      })
    end

    assert_raise ArgumentError, ~r/ui_slider requires a non-empty string label/, fn ->
      UI.slider(%{id: "volume", value: 50, "phx-change": "volume_changed"})
    end
  end

  test "builds controlled field feedback and input submission contracts" do
    input =
      UI.input(%{
        id: "name",
        label: "Name",
        value: "",
        focus_request: 2,
        "phx-change": "name_changed",
        "phx-submit": "save"
      })

    assert %Element{
             type: :div,
             children: [
               %Element{type: :text, children: ["Name (required)"]},
               ^input,
               %Element{
                 type: :text,
                 attrs: [style: [color: {:rgb, 0xEF4444}]],
                 children: ["Error: Enter a name."]
               }
             ]
           } =
             UI.field(%{
               label: "Name",
               required: true,
               help: "Shown to collaborators.",
               error: "Enter a name.",
               children: [input]
             })

    assert input.attrs[:focus_request] == 2
    assert input.attrs[:"phx-submit"] == "save"

    assert_raise ArgumentError, ~r/requires exactly one element child/, fn ->
      UI.field(%{label: "Name", children: []})
    end
  end

  test "requires event handlers for editable controlled components" do
    assert_raise ArgumentError,
                 ~r/ui_input :phx-change must be a non-empty string; got: nil/,
                 fn ->
                   UI.input(%{id: "name", label: "Name", value: "Ada"})
                 end

    assert %Element{attrs: attrs} =
             UI.input(%{"phx-change" => "name_changed", id: "name", label: "Name", value: "Ada"})

    assert attrs[:"phx-change"] == "name_changed"
    refute Enum.any?(attrs, &(elem(&1, 0) == "phx-change"))

    assert_raise ArgumentError,
                 ~r/received duplicate :phx-change and "phx-change" attributes/,
                 fn ->
                   UI.input(%{
                     "phx-change" => "other_name_changed",
                     id: "name",
                     label: "Name",
                     value: "Ada",
                     "phx-change": "name_changed"
                   })
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

  test "builds variable-height virtual collections from complete stable snapshots" do
    first = UI.virtual_item(%{id: "message-1", children: ["Short"]})

    second =
      UI.virtual_item(%{
        id: "message-2",
        children: ["A much longer message that may wrap to several native lines."]
      })

    assert %Element{
             type: :ui_virtual_collection,
             attrs: attrs,
             children: [^first, ^second]
           } =
             UI.virtual_collection(%{
               :"phx-range" => "visible_messages",
               id: "transcript",
               label: "Conversation",
               alignment: "bottom",
               overdraw: 320,
               reveal: "message-1",
               reveal_request: 2,
               reveal_strategy: "top",
               follow: "tail",
               follow_request: 4,
               children: [first, second]
             })

    assert attrs[:alignment] == "bottom"
    assert attrs[:overdraw] == 320
    assert attrs[:reveal_request] == 2
    assert attrs[:follow] == "tail"
    assert attrs[:follow_request] == 4
    assert attrs[:"phx-range"] == "visible_messages"
  end

  test "validates bounded variable collection identity and requests" do
    item = UI.virtual_item(%{id: "message-1"})

    assert_raise ArgumentError, ~r/only accepts ui_virtual_item children/, fn ->
      UI.virtual_collection(%{
        id: "transcript",
        label: "Conversation",
        children: [UI.virtual_list_item(%{id: "message-1"})]
      })
    end

    assert_raise ArgumentError, ~r/item IDs must be unique/, fn ->
      UI.virtual_collection(%{
        id: "transcript",
        label: "Conversation",
        children: [item, item]
      })
    end

    assert_raise ArgumentError, ~r/no larger than 128 bytes/, fn ->
      UI.virtual_collection(%{
        id: "transcript",
        label: "Conversation",
        children: [UI.virtual_item(%{id: String.duplicate("x", 129)})]
      })
    end

    assert_raise ArgumentError, ~r/reveal must identify a child/, fn ->
      UI.virtual_collection(%{
        id: "transcript",
        label: "Conversation",
        reveal: "missing",
        children: [item]
      })
    end

    assert_raise ArgumentError, ~r/follow_request must be a non-negative integer/, fn ->
      UI.virtual_collection(%{
        id: "transcript",
        label: "Conversation",
        follow_request: -1,
        children: [item]
      })
    end

    assert_raise ArgumentError, ~r/received unsupported attributes: :total_count/, fn ->
      UI.virtual_collection(%{
        id: "transcript",
        label: "Conversation",
        total_count: 10,
        children: [item]
      })
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
