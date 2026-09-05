defmodule GPUI.Template.ComponentsTest do
  use ExUnit.Case, async: false

  setup do
    previous = Application.get_env(:gpui, :unknown_classes)
    Application.put_env(:gpui, :unknown_classes, :keep)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:gpui, :unknown_classes, previous),
        else: Application.delete_env(:gpui, :unknown_classes)
    end)
  end

  import GPUI.Template, only: [sigil_GPUI: 2]

  alias GPUI.UI
  alias GPUI.UI.Overlay

  def card(assigns) do
    %GPUI.Element{type: :card, attrs: [title: assigns.title], children: assigns.children}
  end

  test "tooltip compiles aliased named slots into a textual native contract" do
    assert %GPUI.Element{
             type: :ui_tooltip,
             attrs: attrs,
             children: [%GPUI.Element{type: :ui_tooltip_trigger, children: [trigger]}]
           } =
             ~GPUI"""
             <Overlay.tooltip id="save-help" delay={250}>
               <:trigger><UI.button id="save" label="Save" /></:trigger>
               <:content>Save the current document</:content>
             </Overlay.tooltip>
             """

    assert attrs[:id] == "save-help"
    assert attrs[:text] == "Save the current document"
    assert attrs[:delay] == 250.0
    refute attrs[:hoverable]
    assert %GPUI.Element{type: :ui_button} = trigger
  end

  test "split compiles a bounded controlled two-pane contract" do
    assert %GPUI.Element{
             type: :ui_split,
             attrs: split_attrs,
             children: [%GPUI.Element{type: :div}, %GPUI.Element{type: :div}]
           } =
             ~GPUI"""
             <UI.split
               id="workspace-split"
               orientation="horizontal"
               sizes={[240, 560]}
               min_sizes={[160, 320]}
               resize_request={2}
               phx-change="split_changed"
             >
               <div>Navigation</div>
               <div>Content</div>
             </UI.split>
             """

    assert split_attrs[:sizes] == [240, 560]
    assert split_attrs[:min_sizes] == [160, 320]
    assert split_attrs[:max_sizes] == [100_000.0, 100_000.0]
    assert split_attrs[:resize_request] == 2
    assert split_attrs[:"phx-change"] == "split_changed"
  end

  test "split validates its bounded two-pane contract" do
    assert_raise ArgumentError, ~r/sizes must contain exactly two/, fn ->
      UI.split(%{
        id: "split",
        sizes: [200],
        phx_change: "resize",
        children: [%GPUI.Element{type: :div}, %GPUI.Element{type: :div}]
      })
    end

    assert_raise ArgumentError, ~r/sizes must be within/, fn ->
      UI.split(%{
        id: "split",
        sizes: [100, 400],
        min_sizes: [180, 200],
        phx_change: "resize",
        children: [%GPUI.Element{type: :div}, %GPUI.Element{type: :div}]
      })
    end
  end

  test "tooltip requires textual content" do
    trigger = %GPUI.Template.Component.Slot{children: ["Open"]}
    content = %GPUI.Template.Component.Slot{children: [%GPUI.Element{type: :div}]}

    assert_raise ArgumentError, ~r/must be textual/, fn ->
      Overlay.tooltip(%{
        id: "help",
        trigger: [trigger],
        content: [content],
        children: []
      })
    end
  end

  test "dialog compiles optional trigger and arbitrary content slots" do
    assert %GPUI.Element{
             type: :ui_dialog,
             attrs: attrs,
             children: [
               %GPUI.Element{type: :ui_dialog_trigger},
               %GPUI.Element{type: :ui_dialog_content, children: [content]}
             ]
           } =
             ~GPUI"""
             <Overlay.dialog
               id="settings-dialog"
               open={true}
               title="Settings"
               width={520}
               phx-change="dialog_changed"
             >
               <:trigger><UI.button id="settings" label="Settings" /></:trigger>
               <:content><UI.input id="display-name" label="Display name" value="Ada" phx-change="name_changed" /></:content>
             </Overlay.dialog>
             """

    assert attrs[:id] == "settings-dialog"
    assert attrs[:open]
    assert attrs[:title] == "Settings"
    assert attrs[:width] == 520.0
    assert attrs[:"phx-change"] == "dialog_changed"
    assert %GPUI.Element{type: :ui_input} = content
  end

  test "dialog requires one content slot" do
    assert_raise ArgumentError, ~r/exactly one :content slot/, fn ->
      Overlay.dialog(%{id: "dialog", title: "Dialog", children: []})
    end
  end

  test "dropdown menus compile repeated textual item slots" do
    assert %GPUI.Element{
             type: :ui_dropdown_menu,
             attrs: attrs,
             children: [
               %GPUI.Element{type: :ui_dropdown_menu_trigger, children: [trigger]},
               %GPUI.Element{type: :ui_dropdown_menu_item, attrs: first_attrs},
               %GPUI.Element{type: :ui_dropdown_menu_item, attrs: second_attrs}
             ]
           } =
             ~GPUI"""
             <Overlay.dropdown_menu
               id="file-menu"
               label="File menu"
               open={true}
               phx-change="menu_open_changed"
               phx-select="menu_selected"
             >
               <:trigger><UI.button id="file-trigger" label="File" /></:trigger>
               <:item value="new">New file</:item>
               <:item value="delete" disabled={true} checked={true}>Delete</:item>
             </Overlay.dropdown_menu>
             """

    assert attrs[:id] == "file-menu"
    assert attrs[:open]
    assert attrs[:"phx-change"] == "menu_open_changed"
    assert attrs[:"phx-select"] == "menu_selected"
    assert %GPUI.Element{type: :ui_button} = trigger
    assert first_attrs[:value] == "new"
    assert first_attrs[:label] == "New file"
    refute first_attrs[:disabled]
    assert second_attrs[:value] == "delete"
    assert second_attrs[:label] == "Delete"
    assert second_attrs[:disabled]
    assert second_attrs[:checked]
  end

  test "dropdown menus validate items" do
    trigger = %GPUI.Template.Component.Slot{children: ["Open"]}
    duplicate = %GPUI.Template.Component.Slot{attrs: [value: "same"], children: ["Item"]}

    assert_raise ArgumentError, ~r/at least one :item/, fn ->
      Overlay.dropdown_menu(%{
        id: "menu",
        label: "Menu",
        trigger: [trigger],
        children: []
      })
    end

    assert_raise ArgumentError, ~r/values must be unique/, fn ->
      Overlay.dropdown_menu(%{
        id: "menu",
        label: "Menu",
        trigger: [trigger],
        item: [duplicate, duplicate],
        children: []
      })
    end
  end

  test "popover uses explicit trigger and content slots" do
    assert %GPUI.Element{
             type: :ui_popover,
             attrs: attrs,
             children: [
               %GPUI.Element{type: :ui_popover_trigger, children: ["Open"]},
               %GPUI.Element{type: :ui_popover_content, children: [content]}
             ]
           } =
             ~GPUI"""
             <Overlay.popover id="account-menu" label="Account" open={true} phx-change="menu_changed">
               <:trigger>Open</:trigger>
               <:content>
                 <UI.button id="profile" label="Profile" phx-click="profile" />
               </:content>
             </Overlay.popover>
             """

    assert attrs[:id] == "account-menu"
    assert attrs[:open]
    assert attrs[:appearance]
    assert attrs[:closable]
    assert attrs[:"phx-change"] == "menu_changed"
    assert %GPUI.Element{type: :ui_button} = content
  end

  test "popover validates its structural slots" do
    trigger = %GPUI.Template.Component.Slot{children: ["Open"]}

    assert_raise ArgumentError, ~r/exactly one :content slot/, fn ->
      Overlay.popover(%{id: "menu", label: "Menu", trigger: [trigger], children: []})
    end
  end

  test "overlays require semantic trigger labels and dialog titles" do
    trigger = %GPUI.Template.Component.Slot{children: ["Open"]}
    content = %GPUI.Template.Component.Slot{children: ["Content"]}
    item = %GPUI.Template.Component.Slot{attrs: [value: "open"], children: ["Open"]}

    assert_raise ArgumentError, ~r/ui_popover :label must be a non-empty string/, fn ->
      Overlay.popover(%{id: "popover", trigger: [trigger], content: [content], children: []})
    end

    assert_raise ArgumentError, ~r/ui_dropdown_menu :label must be a non-empty string/, fn ->
      Overlay.dropdown_menu(%{
        id: "menu",
        trigger: [trigger],
        item: [item],
        children: []
      })
    end

    assert_raise ArgumentError, ~r/ui_dialog :title must be a non-empty string/, fn ->
      Overlay.dialog(%{id: "dialog", content: [content], children: []})
    end
  end

  test "template diagnostics reject internal component tags and duplicate attributes" do
    assert_raise CompileError,
                 ~r/native component tag <ui_button> is internal.*GPUI.UI.button/,
                 fn ->
                   GPUI.Template.compile(~s(<ui_button id="save" />), __ENV__)
                 end

    assert_raise CompileError, ~r/unsupported GPUI tag <canvas>/, fn ->
      GPUI.Template.compile("<canvas />", __ENV__)
    end

    assert_raise CompileError, ~r/duplicate GPUI attribute "id"/, fn ->
      GPUI.Template.compile(~s(<div id="first" id="second" />), __ENV__)
    end
  end

  test "native UI components require stable ids" do
    assert_raise ArgumentError, ~r/requires :id to be a non-empty string; got: nil/, fn ->
      GPUI.UI.button(%{children: []})
    end
  end

  test "option components validate values while allowing asynchronous combobox options" do
    assert_raise ArgumentError, ~r/option values must be unique/, fn ->
      GPUI.UI.select(%{id: "language", options: ["Rust", "Rust"]})
    end

    assert_raise ArgumentError, ~r/is not present in options/, fn ->
      GPUI.UI.select(%{id: "language", value: "zig", options: ["Rust"]})
    end

    combobox =
      GPUI.UI.combobox(%{
        id: "framework",
        label: "Framework",
        value: "LiveView",
        options: [],
        "phx-change": "framework_changed"
      })

    assert combobox.attrs[:value] == "LiveView"
  end

  test "radio groups validate controlled values and disabled options" do
    assert_raise ArgumentError, ~r/is not present in options/, fn ->
      GPUI.UI.radio_group(%{id: "plan", value: "missing", options: ["Free"]})
    end

    radio =
      GPUI.UI.radio_group(%{
        id: "plan",
        label: "Plan",
        value: "pro",
        options: [%{label: "Pro", value: "pro", disabled: true}],
        "phx-change": "plan_changed"
      })

    assert [%{disabled: true}] = radio.attrs[:options]
  end

  test "accordion validates controlled expanded item IDs" do
    item = GPUI.UI.accordion_item(%{id: "account", title: "Account", children: []})

    assert_raise ArgumentError, ~r/must identify accordion items/, fn ->
      GPUI.UI.accordion(%{id: "details", expanded: ["missing"], children: [item]})
    end

    assert_raise ArgumentError, ~r/requires multiple=\{true\}/, fn ->
      GPUI.UI.accordion(%{
        id: "details",
        expanded: ["account", "security"],
        children: [item, GPUI.UI.accordion_item(%{id: "security", title: "Security"})]
      })
    end
  end

  test "tabs require a controlled value from their options" do
    assert_raise ArgumentError, ~r/is not present in options/, fn ->
      GPUI.UI.tabs(%{id: "section", value: "missing", options: ["General"]})
    end
  end

  test "slider validates its numeric contract" do
    assert_raise ArgumentError, ~r/min must be less than max/, fn ->
      GPUI.UI.slider(%{id: "invalid", min: 10, max: 10})
    end

    assert_raise ArgumentError, ~r/value must be between min and max/, fn ->
      GPUI.UI.slider(%{id: "invalid", value: 11, min: 0, max: 10})
    end

    assert_raise ArgumentError, ~r/logarithmic scale requires min greater than zero/, fn ->
      GPUI.UI.slider(%{id: "invalid", min: 0, scale: "logarithmic"})
    end
  end

  @tag :native
  test "text surface validates and serializes its native buffer reference" do
    {:ok, buffer} = GPUI.Text.Buffer.new("hello")

    range = GPUI.Text.Range.new(GPUI.Text.Position.new(0, 0), GPUI.Text.Position.new(0, 2))

    assert %{
             type: :text_surface,
             attrs: %{
               :"phx-transaction" => "changed",
               :"phx-submit" => "submitted",
               :"phx-viewport-change" => "viewport",
               :"phx-geometry-change" => "geometry",
               :"phx-range-geometry-change" => "ranges",
               :"phx-hit-test" => "hit",
               buffer: ref,
               decorations: [
                 %{
                   range: %{
                     start: %{line: 0, utf16_offset: 0},
                     end: %{line: 0, utf16_offset: 2}
                   },
                   background: 0x112233,
                   underline: 0x445566,
                   underline_style: "dashed"
                 }
               ],
               style_runs: [
                 %{
                   range: %{
                     start: %{line: 0, utf16_offset: 0},
                     end: %{line: 0, utf16_offset: 2}
                   },
                   color: 0xF97316,
                   font_weight: "semibold",
                   font_style: "italic"
                 }
               ],
               geometry_ranges: [
                 %{
                   start: %{line: 0, utf16_offset: 0},
                   end: %{line: 0, utf16_offset: 2}
                 }
               ],
               inline_projections: [
                 %{
                   position: %{line: 0, utf16_offset: 2},
                   text: " ghost",
                   color: 0x94A3B8
                 }
               ],
               block_projections: [
                 %{
                   line: 0,
                   text: "note",
                   placement: "after",
                   height: 24,
                   color: 0xCBD5E1,
                   background: 0x1E293B
                 }
               ],
               scroll_request: 3,
               scroll_to: %{line: 0, utf16_offset: 2},
               id: "document",
               focus_request: 2,
               auto_grow: true,
               min_lines: 2,
               max_lines: 6,
               submit_policy: "submit",
               tab_size: 4
             }
           } =
             ~GPUI"""
             <text_surface
               id="document"
               buffer={buffer}
               decorations={[
                 GPUI.Text.Decoration.new(range,
                   background: 0x112233,
                   underline: 0x445566,
                   underline_style: :dashed
                 )
               ]}
               geometry_ranges={[range]}
               style_runs={[
                 GPUI.Text.StyleRun.new(range,
                   color: 0xF97316,
                   font_weight: :semibold,
                   font_style: :italic
                 )
               ]}
               inline_projections={[
                 GPUI.Text.InlineProjection.new(GPUI.Text.Position.new(0, 2), " ghost")
               ]}
               block_projections={[
                 GPUI.Text.BlockProjection.new(0, "note", background: 0x1E293B)
               ]}
               scroll_request={3}
               scroll_to={GPUI.Text.Position.new(0, 2)}
               focus_request={2}
               auto_grow={true}
               min_lines={2}
               max_lines={6}
               submit_policy="submit"
               tab_size={4}
               phx-transaction="changed"
               phx-submit="submitted"
               phx-viewport-change="viewport"
               phx-geometry-change="geometry"
               phx-range-geometry-change="ranges"
               phx-hit-test="hit"
             />
             """
             |> GPUI.Element.to_payload()

    assert is_reference(ref)

    assert_raise ArgumentError, ~r/must be a GPUI.Text.Buffer/, fn ->
      ~GPUI"""
      <text_surface id="invalid" buffer="not-a-buffer" />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/min_lines must be less than or equal to max_lines/, fn ->
      ~GPUI"""
      <text_surface id="invalid-lines" buffer={buffer} min_lines={9} max_lines={3} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/max_lines must be at most 64/, fn ->
      ~GPUI"""
      <text_surface id="too-tall" buffer={buffer} max_lines={65} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/requires a non-empty phx-submit event/, fn ->
      ~GPUI"""
      <text_surface id="missing-submit" buffer={buffer} submit_policy="submit" />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/at most 64 GPUI.Text.Range values/, fn ->
      ranges = List.duplicate(range, 65)

      ~GPUI"""
      <text_surface id="too-many" buffer={buffer} geometry_ranges={ranges} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/at most 256 GPUI.Text.Decoration values/, fn ->
      decorations = List.duplicate(GPUI.Text.Decoration.new(range), 257)

      ~GPUI"""
      <text_surface id="too-decorated" buffer={buffer} decorations={decorations} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/at most 512 bounded GPUI.Text.StyleRun values/, fn ->
      runs = List.duplicate(GPUI.Text.StyleRun.new(range, color: 0xF97316), 513)

      ~GPUI"""
      <text_surface id="too-styled" buffer={buffer} style_runs={runs} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/at most 128 bounded GPUI.Text.InlineProjection values/, fn ->
      projections =
        List.duplicate(GPUI.Text.InlineProjection.new(GPUI.Text.Position.new(0, 0), "x"), 129)

      ~GPUI"""
      <text_surface id="too-projected" buffer={buffer} inline_projections={projections} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/at most 64 bounded GPUI.Text.BlockProjection values/, fn ->
      projections = List.duplicate(GPUI.Text.BlockProjection.new(0, "x"), 65)

      ~GPUI"""
      <text_surface id="too-blocked" buffer={buffer} block_projections={projections} />
      """
      |> GPUI.Element.to_payload()
    end
  end

  test "serialized component trees reject duplicate stable ids" do
    tree =
      ~GPUI"""
      <div>
        <GPUI.UI.button id="duplicate" label="One" />
        <GPUI.UI.input id="duplicate" label="Duplicate" value="" phx-change="name_changed" />
      </div>
      """

    assert_raise ArgumentError, ~r/duplicate GPUI component id "duplicate"/, fn ->
      GPUI.Element.to_payload(tree)
    end
  end
end
