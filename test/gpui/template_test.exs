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
                   %GPUI.Element{type: :icon}
                 ]
               }
             ]
           } =
             ~GPUI"""
             <list>
               <item>
                 <span>Label</span>
                 <icon>+</icon>
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
               <GPUI.UI.button id="save" variant="primary" phx-click="save">Save</GPUI.UI.button>
               <GPUI.UI.checkbox
                 id="remember"
                 label="Remember me"
                 checked={checked}
                 phx-change="remember"
               />
               <GPUI.UI.input
                 id="name"
                 value="Ada"
                 placeholder="Name"
                 cleanable={true}
                 phx-change="name_changed"
               />
               <GPUI.UI.select
                 id="language"
                 value="rust"
                 options={options}
                 phx-change="language_changed"
               />
               <GPUI.UI.combobox
                 id="framework"
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
               <:content><UI.input id="display-name" value="Ada" /></:content>
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
      Overlay.dialog(%{id: "dialog", children: []})
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
      Overlay.dropdown_menu(%{id: "menu", trigger: [trigger], children: []})
    end

    assert_raise ArgumentError, ~r/values must be unique/, fn ->
      Overlay.dropdown_menu(%{
        id: "menu",
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
             <Overlay.popover id="account-menu" open={true} phx-change="menu_changed">
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
      Overlay.popover(%{id: "menu", trigger: [trigger], children: []})
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

    combobox = GPUI.UI.combobox(%{id: "framework", value: "LiveView", options: []})
    assert combobox.attrs[:value] == "LiveView"
  end

  test "radio groups validate controlled values and disabled options" do
    assert_raise ArgumentError, ~r/is not present in options/, fn ->
      GPUI.UI.radio_group(%{id: "plan", value: "missing", options: ["Free"]})
    end

    radio =
      GPUI.UI.radio_group(%{
        id: "plan",
        value: "pro",
        options: [%{label: "Pro", value: "pro", disabled: true}]
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

  test "serialized component trees reject duplicate stable ids" do
    tree =
      ~GPUI"""
      <div>
        <GPUI.UI.button id="duplicate" label="One" />
        <GPUI.UI.input id="duplicate" value="" />
      </div>
      """

    assert_raise ArgumentError, ~r/duplicate GPUI component id "duplicate"/, fn ->
      GPUI.Element.to_payload(tree)
    end
  end
end
