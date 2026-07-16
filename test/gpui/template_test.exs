defmodule GPUI.TemplateTest do
  use ExUnit.Case, async: true

  import GPUI.Template, only: [sigil_GPUI: 2]

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

  test "native UI components require stable ids" do
    assert_raise ArgumentError, ~r/requires a non-empty string id/, fn ->
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
