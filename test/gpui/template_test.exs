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

    assert %GPUI.Element{
             type: :div,
             children: [
               %GPUI.Element{
                 type: :ui_button,
                 attrs: button_attrs,
                 children: ["Save"]
               },
               %GPUI.Element{type: :ui_checkbox, attrs: checkbox_attrs},
               %GPUI.Element{type: :ui_input, attrs: input_attrs}
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
  end

  test "native UI components require stable ids" do
    assert_raise ArgumentError, ~r/requires a non-empty string id/, fn ->
      GPUI.UI.button(%{children: []})
    end
  end
end
