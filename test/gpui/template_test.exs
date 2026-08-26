defmodule GPUI.TemplateTest do
  use ExUnit.Case, async: true

  import GPUI.Template, only: [sigil_GPUI: 2]

  alias GPUI.UI
  alias GPUI.UI.Overlay

  def card(assigns) do
    %GPUI.Element{type: :card, attrs: [title: assigns.title], children: assigns.children}
  end

  defmodule Demo.Card do
    def render(assigns) do
      %GPUI.Element{type: :remote_card, attrs: [title: assigns.title], children: assigns.children}
    end
  end

  defmodule Demo.Components do
    def badge(assigns) do
      %GPUI.Element{type: :badge, attrs: [label: assigns.label], children: assigns.children}
    end
  end

  test "builds element trees from HEEx-style templates" do
    assert %GPUI.Element{
             type: :div,
             attrs: [style: [display: :flex, flex_direction: :column, align_items: :center]],
             children: [%GPUI.Element{type: :text, children: ["Hello"]}]
           } =
             ~GPUI"""
             <div class="flex flex-col items-center">
               <text>Hello</text>
             </div>
             """
  end

  test "builds and validates neutral anchored layers" do
    payload =
      ~GPUI"""
      <layer
        id="completion"
        anchor="bottom_left"
        position_mode="window"
        position_x={240}
        position_y={120}
        offset_y={6}
        fit="snap_with_margin"
        margin={8}
        priority={12}
      >
        <div class="w-[320px] h-12" />
      </layer>
      """
      |> GPUI.Element.to_payload()

    assert payload.type == :layer
    assert payload.attrs.id == "completion"
    assert payload.attrs.anchor == "bottom_left"
    assert payload.attrs.position_mode == "window"
    assert payload.attrs.position_x == 240
    assert payload.attrs.position_y == 120
    assert payload.attrs.offset_y == 6
    assert payload.attrs.fit == "snap_with_margin"
    assert payload.attrs.margin == 8
    assert payload.attrs.priority == 12
    assert [%{type: :div}] = payload.children

    assert_raise ArgumentError, "layer requires exactly one child", fn ->
      ~GPUI"""
      <layer id="empty" />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/integer from 0 through 1024/, fn ->
      ~GPUI"""
      <layer id="too-high" priority={1025}><div /></layer>
      """
      |> GPUI.Element.to_payload()
    end
  end

  test "keeps ordinary positioning Tailwind-like and layer geometry explicit" do
    ordinary =
      ~GPUI"""
      <div class="relative w-full h-full">
        <div class="absolute top-2 right-2" />
      </div>
      """
      |> GPUI.Element.to_payload()

    assert ordinary.attrs.style == [position: :relative, width: :full, height: :full]
    assert [%{attrs: %{style: child_style}}] = ordinary.children
    assert child_style == [position: :absolute, top: [:px, 8.0], right: [:px, 8.0]]

    layer =
      ~GPUI"""
      <layer id="runtime-layer" position_x={120} position_y={80}>
        <div class="w-40 rounded-lg bg-slate-800" />
      </layer>
      """
      |> GPUI.Element.to_payload()

    refute Map.has_key?(layer.attrs, :style)
    assert layer.attrs.position_x == 120
    assert layer.attrs.position_y == 80
    assert [%{attrs: %{style: layer_child_style}}] = layer.children
    assert layer_child_style[:width] == [:px, 160.0]
    assert layer_child_style[:border_radius] == [:px, 8.0]
    assert layer_child_style[:background] == [:rgb, 0x1E293B]
  end

  test "serializes bounded neutral accessibility metadata" do
    role = "button"
    label = "Retry connection"

    payload =
      ~GPUI"""
      <div
        id="retry"
        accessibility_role={role}
        accessibility_label={label}
        accessibility_description="Attempts to reconnect to the remote host"
        phx-click="retry"
      />
      """
      |> GPUI.Element.to_payload()

    assert payload.attrs.accessibility_role == "button"
    assert payload.attrs.accessibility_label == "Retry connection"

    assert payload.attrs.accessibility_description ==
             "Attempts to reconnect to the remote host"

    assert_raise ArgumentError, ~r/one of.*button/, fn ->
      ~GPUI"""
      <div id="bad-role" accessibility_role="made_up" />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/accessibility metadata requires a non-empty string id/, fn ->
      ~GPUI"""
      <div accessibility_role="button" accessibility_label="Retry" />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/requires :accessibility_role/, fn ->
      ~GPUI"""
      <div id="unnamed-role" accessibility_label="Retry" />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/at most 512 bytes/, fn ->
      %GPUI.Element{
        type: :div,
        attrs: [
          id: "long-label",
          accessibility_role: "button",
          accessibility_label: String.duplicate("a", 513)
        ]
      }
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/at most 2048 bytes/, fn ->
      %GPUI.Element{
        type: :div,
        attrs: [
          id: "long-description",
          accessibility_role: "button",
          accessibility_description: String.duplicate("a", 2049)
        ]
      }
      |> GPUI.Element.to_payload()
    end
  end

  test "validates and serializes role-constrained accessibility states" do
    payload =
      ~GPUI"""
      <div
        id="notifications"
        accessibility_role="switch"
        accessibility_label="Notifications"
        accessibility_checked={:mixed}
        phx-click="toggle"
      />
      """
      |> GPUI.Element.to_payload()

    assert payload.attrs.accessibility_checked == "mixed"

    tree_item =
      ~GPUI"""
      <item
        id="project-1"
        accessibility_role="tree_item"
        accessibility_label="Project"
        accessibility_selected={true}
        accessibility_expanded={false}
      />
      """
      |> GPUI.Element.to_payload()

    assert tree_item.attrs.accessibility_selected
    refute tree_item.attrs.accessibility_expanded

    splitter =
      ~GPUI"""
      <div
        id="divider"
        accessibility_role="splitter"
        accessibility_label="Resize sidebar"
        accessibility_orientation="vertical"
      />
      """
      |> GPUI.Element.to_payload()

    assert splitter.attrs.accessibility_orientation == "vertical"

    slider =
      ~GPUI"""
      <div
        id="volume"
        accessibility_role="slider"
        accessibility_label="Volume"
        accessibility_value="75 percent"
      />
      """
      |> GPUI.Element.to_payload()

    assert slider.attrs.accessibility_value == "75 percent"

    assert_raise ArgumentError, ~r/accessibility_checked.*role "button"/, fn ->
      ~GPUI"""
      <div
        id="bad-check"
        accessibility_role="button"
        accessibility_checked={true}
        phx-click="bad"
      />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/accessibility_selected.*role "switch"/, fn ->
      ~GPUI"""
      <div
        id="bad-selected"
        accessibility_role="switch"
        accessibility_selected={true}
        phx-click="bad"
      />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/true, false, or :mixed/, fn ->
      %GPUI.Element{
        type: :div,
        attrs: [
          id: "bad-state",
          accessibility_role: "switch",
          accessibility_checked: :yes,
          "phx-click": "bad"
        ]
      }
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/at most 512 bytes/, fn ->
      %GPUI.Element{
        type: :div,
        attrs: [
          id: "long-value",
          accessibility_role: "slider",
          accessibility_value: String.duplicate("v", 513)
        ]
      }
      |> GPUI.Element.to_payload()
    end
  end

  test "interactive accessibility roles require an event while structural roles remain semantic" do
    assert_raise ArgumentError, ~r/role "switch" requires phx-click/, fn ->
      ~GPUI"""
      <div id="inert-switch" accessibility_role="switch" accessibility_label="Inert" />
      """
      |> GPUI.Element.to_payload()
    end

    structural =
      ~GPUI"""
      <div id="region" accessibility_role="group" accessibility_label="Information" />
      """
      |> GPUI.Element.to_payload()

    assert structural.attrs.accessibility_role == "group"
    refute Map.has_key?(structural.attrs, :"phx-click")
  end

  test "serializes disabled accessibility state only for supported roles" do
    disabled =
      ~GPUI"""
      <div
        id="notifications-disabled"
        accessibility_role="switch"
        accessibility_label="Notifications"
        accessibility_checked={true}
        accessibility_disabled={true}
        phx-click="toggle"
      />
      """
      |> GPUI.Element.to_payload()

    assert disabled.attrs.accessibility_disabled
    assert disabled.attrs.accessibility_checked == "true"

    assert_raise ArgumentError, ~r/accessibility_disabled.*role "group"/, fn ->
      ~GPUI"""
      <div id="disabled-group" accessibility_role="group" accessibility_disabled={true} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/accessibility_disabled.*boolean/, fn ->
      %GPUI.Element{
        type: :div,
        attrs: [
          id: "invalid-disabled",
          accessibility_role: "switch",
          accessibility_disabled: :yes,
          "phx-click": "toggle"
        ]
      }
      |> GPUI.Element.to_payload()
    end
  end

  test "serializes opt-in bounds observation on identified containers" do
    payload =
      ~GPUI"""
      <div id="anchor" phx-bounds-change="anchor-bounds" class="w-24 h-8" />
      """
      |> GPUI.Element.to_payload()

    assert payload.attrs.id == "anchor"
    assert payload.attrs[:"phx-bounds-change"] == "anchor-bounds"
    assert payload.attrs.style == [width: [:px, 96.0], height: [:px, 32.0]]

    assert_raise ArgumentError, ~r/requires a non-empty string id/, fn ->
      ~GPUI"""
      <div phx-bounds-change="missing-id" />
      """
      |> GPUI.Element.to_payload()
    end
  end

  test "serializes neutral native window control regions" do
    for control <- ~w(drag close maximize minimize) do
      payload =
        ~GPUI"""
        <div window_control={control}><text>{control}</text></div>
        """
        |> GPUI.Element.to_payload()

      assert payload.attrs.window_control == control
    end

    assert_raise ArgumentError, ~r/window_control/, fn ->
      ~GPUI"""
      <div window_control="menu" />
      """
      |> GPUI.Element.to_payload()
    end
  end

  test "serializes bounded monotonic motion contracts on identified containers" do
    payload =
      ~GPUI"""
      <div
        id="notice"
        motion_request={2}
        motion_duration={240}
        motion_delay={40}
        motion_easing="ease_in_out"
        motion_from_opacity={0.25}
        motion_from_x={-12}
        motion_from_y={8}
      />
      """
      |> GPUI.Element.to_payload()

    assert payload.attrs == %{
             id: "notice",
             motion_request: 2,
             motion_duration: 240,
             motion_delay: 40,
             motion_easing: "ease_in_out",
             motion_from_opacity: 0.25,
             motion_from_x: -12,
             motion_from_y: 8
           }

    assert_raise ArgumentError, ~r/motion_request requires a non-empty string id/, fn ->
      ~GPUI"""
      <div motion_request={1} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/motion_duration.*no greater than 10000/, fn ->
      ~GPUI"""
      <div id="slow" motion_request={1} motion_duration={10_001} />
      """
      |> GPUI.Element.to_payload()
    end

    assert_raise ArgumentError, ~r/motion_from_opacity.*0.0 through 1.0/, fn ->
      ~GPUI"""
      <div id="opaque" motion_request={1} motion_from_opacity={1.5} />
      """
      |> GPUI.Element.to_payload()
    end
  end

  test "serializes semantic accessibility on primitive buttons" do
    button =
      ~GPUI"""
      <button id="save" phx-click="save" accessibility_label="Save changes">
        <text>Save</text>
      </button>
      """
      |> GPUI.Element.to_payload()

    assert button.attrs.accessibility_label == "Save changes"
    assert button.attrs[:"phx-click"] == "save"
  end

  test "serializes monotonic focus contracts on focusable primitives" do
    button =
      ~GPUI"""
      <button
        id="trigger"
        focus_request={2}
        phx-focus="trigger-focused"
        phx-blur="trigger-blurred"
      >
        <text>Trigger</text>
      </button>
      """
      |> GPUI.Element.to_payload()

    assert button.attrs.id == "trigger"
    assert button.attrs.focus_request == 2
    assert button.attrs[:"phx-focus"] == "trigger-focused"
    assert button.attrs[:"phx-blur"] == "trigger-blurred"

    input =
      ~GPUI"""
      <text_input id="search" value="" focus_request={1} phx-focus="search-focused" />
      """
      |> GPUI.Element.to_payload()

    assert input.attrs.id == "search"
    assert input.attrs.focus_request == 1

    assert_raise ArgumentError, ~r/focus behavior requires a non-empty string id/, fn ->
      ~GPUI"""
      <button phx-focus="missing-id"><text>Missing</text></button>
      """
      |> GPUI.Element.to_payload()
    end
  end

  test "serializes Tailwind palette alpha through the canonical payload path" do
    payload =
      ~GPUI"""
      <div class="bg-black/40 border border-white/10 text-slate-300/70" />
      """
      |> GPUI.Element.to_payload()

    assert payload.attrs.style == [
             background: [:rgba, 0x00000066],
             border_width: [:px, 1.0],
             border_color: [:rgba, 0xFFFFFF1A],
             color: [:rgba, 0xCBD5E1B3]
           ]
  end

  test "merges normalized classes with dynamic styles at runtime" do
    dynamic_style = [background: {:rgb, 0xFFFFFF}]

    assert %GPUI.Element{
             attrs: [
               style: [
                 background: {:rgb, 0xFFFFFF},
                 display: :flex,
                 gap: {:px, 8.0}
               ]
             ]
           } =
             ~GPUI"""
             <div class="flex gap-2" style={dynamic_style} />
             """
  end

  test "preserves unknown classes after style normalization" do
    assert %GPUI.Element{attrs: attrs} =
             ~GPUI"""
             <div class="flex unknown-class" />
             """

    assert attrs[:style] == [display: :flex]
    assert attrs[:class] == "unknown-class"
  end

  test "supports every tag declared by the native component schema" do
    assert %GPUI.Element{
             type: :list,
             children: [
               %GPUI.Element{
                 type: :item,
                 children: [
                   %GPUI.Element{type: :span},
                   %GPUI.Element{type: :text}
                 ]
               }
             ]
           } =
             ~GPUI"""
             <list>
               <item>
                 <span>Label</span>
                 <text>+</text>
               </item>
             </list>
             """
  end

  test "normalizes styles on text and image elements" do
    assert %GPUI.Element{
             type: :div,
             children: [
               %GPUI.Element{
                 type: :text,
                 attrs: [style: [color: {:rgb, 0xFFFFFF}, font_weight: :bold]]
               },
               %GPUI.Element{type: :img, attrs: image_attrs}
             ]
           } =
             ~GPUI"""
             <div>
               <text class="text-white font-bold">Styled</text>
               <img class="w-10 h-12" raster={%{}} />
             </div>
             """

    assert image_attrs[:style] == [width: {:px, 40.0}, height: {:px, 48.0}]
  end

  test "supports body interpolation" do
    name = "OTP"

    assert %GPUI.Element{children: ["Hello ", "OTP"]} =
             ~GPUI"""
             <text>Hello {name}</text>
             """
  end

  test "calls module render components" do
    assert %GPUI.Element{
             type: :remote_card,
             attrs: [title: "Hello"],
             children: [%GPUI.Element{type: :text, children: ["Body"]}]
           } =
             ~GPUI"""
             <GPUI.TemplateTest.Demo.Card title="Hello">
               <text>Body</text>
             </GPUI.TemplateTest.Demo.Card>
             """
  end

  test "calls remote function components" do
    assert %GPUI.Element{
             type: :badge,
             attrs: [label: "New"],
             children: []
           } =
             ~GPUI"""
             <GPUI.TemplateTest.Demo.Components.badge label="New" />
             """
  end

  test "calls local function components" do
    assert %GPUI.Element{
             type: :card,
             attrs: [title: "Local"],
             children: [%GPUI.Element{type: :text, children: ["Body"]}]
           } =
             ~GPUI"""
             <.card title="Local">
               <text>Body</text>
             </.card>
             """
  end

  test "builds namespaced native UI components" do
    checked = true
    options = [{"Rust", "rust"}, %{label: "Elixir", value: "elixir"}]

    assert %GPUI.Element{
             type: :div,
             children: [
               %GPUI.Element{
                 type: :ui_button,
                 attrs: button_attrs,
                 children: ["Save"]
               },
               %GPUI.Element{type: :ui_checkbox, attrs: checkbox_attrs},
               %GPUI.Element{type: :ui_input, attrs: input_attrs},
               %GPUI.Element{type: :ui_select, attrs: select_attrs},
               %GPUI.Element{type: :ui_combobox, attrs: combobox_attrs},
               %GPUI.Element{type: :ui_switch, attrs: switch_attrs},
               %GPUI.Element{type: :ui_radio_group, attrs: radio_attrs},
               %GPUI.Element{
                 type: :ui_accordion,
                 attrs: accordion_attrs,
                 children: [
                   %GPUI.Element{type: :ui_accordion_item, attrs: accordion_item_attrs}
                 ]
               },
               %GPUI.Element{type: :ui_tabs, attrs: tabs_attrs},
               %GPUI.Element{type: :ui_slider, attrs: slider_attrs}
             ]
           } =
             ~GPUI"""
             <div>
               <GPUI.UI.button id="save" label="Save" variant="primary" phx-click="save">Save</GPUI.UI.button>
               <GPUI.UI.checkbox
                 id="remember"
                 label="Remember me"
                 checked={checked}
                 phx-change="remember"
               />
               <GPUI.UI.input
                 id="name"
                 label="Name"
                 value="Ada"
                 placeholder="Name"
                 cleanable={true}
                 phx-change="name_changed"
               />
               <GPUI.UI.select
                 id="language"
                 label="Language"
                 value="rust"
                 options={options}
                 phx-change="language_changed"
               />
               <GPUI.UI.combobox
                 id="framework"
                 label="Framework"
                 options={["Phoenix", "LiveView"]}
                 search_placeholder="Search frameworks"
                 phx-change="framework_changed"
                 phx-search="framework_searched"
               />
               <GPUI.UI.switch
                 id="notifications"
                 label="Notifications"
                 checked={true}
                 phx-change="notifications_changed"
               />
               <GPUI.UI.radio_group
                 id="plan"
                 label="Plan"
                 value="pro"
                 options={[
                   %{label: "Free", value: "free"},
                   %{label: "Pro", value: "pro", disabled: true}
                 ]}
                 orientation="horizontal"
                 phx-change="plan_changed"
               />
               <GPUI.UI.accordion
                 id="details"
                 expanded={["account"]}
                 phx-change="details_changed"
               >
                 <GPUI.UI.accordion_item id="account" title="Account">
                   <text>Account details</text>
                 </GPUI.UI.accordion_item>
               </GPUI.UI.accordion>
               <GPUI.UI.tabs
                 id="section"
                 value="general"
                 options={[{"General", "general"}, {"Advanced", "advanced"}]}
                 variant="underline"
                 phx-change="section_changed"
               />
               <GPUI.UI.slider
                 id="volume"
                 label="Volume"
                 value={25}
                 min={0}
                 max={50}
                 step={0.5}
                 phx-change="volume_changed"
                 phx-release="volume_released"
               />
             </div>
             """

    assert button_attrs[:id] == "save"
    assert button_attrs[:variant] == "primary"
    assert button_attrs[:"phx-click"] == "save"
    assert checkbox_attrs[:id] == "remember"
    assert checkbox_attrs[:checked]
    assert checkbox_attrs[:"phx-change"] == "remember"
    assert input_attrs[:id] == "name"
    assert input_attrs[:value] == "Ada"
    assert input_attrs[:cleanable]
    assert input_attrs[:"phx-change"] == "name_changed"
    assert select_attrs[:id] == "language"
    assert select_attrs[:value] == "rust"

    assert select_attrs[:options] == [
             %{label: "Rust", value: "rust"},
             %{label: "Elixir", value: "elixir"}
           ]

    assert select_attrs[:"phx-change"] == "language_changed"
    assert combobox_attrs[:id] == "framework"

    assert combobox_attrs[:options] == [
             %{label: "Phoenix", value: "Phoenix"},
             %{label: "LiveView", value: "LiveView"}
           ]

    assert combobox_attrs[:search_placeholder] == "Search frameworks"
    assert combobox_attrs[:"phx-change"] == "framework_changed"
    assert combobox_attrs[:"phx-search"] == "framework_searched"
    assert switch_attrs[:id] == "notifications"
    assert switch_attrs[:checked]
    assert switch_attrs[:"phx-change"] == "notifications_changed"
    assert radio_attrs[:id] == "plan"
    assert radio_attrs[:value] == "pro"
    assert radio_attrs[:orientation] == "horizontal"
    assert Enum.at(radio_attrs[:options], 1).disabled
    assert radio_attrs[:"phx-change"] == "plan_changed"
    assert accordion_attrs[:id] == "details"
    assert accordion_attrs[:expanded] == ["account"]
    assert accordion_attrs[:bordered]
    assert accordion_attrs[:"phx-change"] == "details_changed"
    assert accordion_item_attrs[:id] == "account"
    assert accordion_item_attrs[:title] == "Account"
    assert tabs_attrs[:id] == "section"
    assert tabs_attrs[:value] == "general"
    assert tabs_attrs[:variant] == "underline"
    assert tabs_attrs[:"phx-change"] == "section_changed"
    assert slider_attrs[:id] == "volume"
    assert slider_attrs[:value] == 25.0
    assert slider_attrs[:min] == 0.0
    assert slider_attrs[:max] == 50.0
    assert slider_attrs[:step] == 0.5
    assert slider_attrs[:"phx-change"] == "volume_changed"
    assert slider_attrs[:"phx-release"] == "volume_released"
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
    trigger = %GPUI.Component.Slot{children: ["Open"]}
    content = %GPUI.Component.Slot{children: [%GPUI.Element{type: :div}]}

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
    trigger = %GPUI.Component.Slot{children: ["Open"]}
    duplicate = %GPUI.Component.Slot{attrs: [value: "same"], children: ["Item"]}

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
    trigger = %GPUI.Component.Slot{children: ["Open"]}

    assert_raise ArgumentError, ~r/exactly one :content slot/, fn ->
      Overlay.popover(%{id: "menu", label: "Menu", trigger: [trigger], children: []})
    end
  end

  test "overlays require semantic trigger labels and dialog titles" do
    trigger = %GPUI.Component.Slot{children: ["Open"]}
    content = %GPUI.Component.Slot{children: ["Content"]}
    item = %GPUI.Component.Slot{attrs: [value: "open"], children: ["Open"]}

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
