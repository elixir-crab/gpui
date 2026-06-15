defmodule GPUITemplateTest do
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
             <GPUITemplateTest.Demo.Card title="Hello">
               <text>Body</text>
             </GPUITemplateTest.Demo.Card>
             """
  end

  test "calls remote function components" do
    assert %GPUI.Element{
             type: :badge,
             attrs: [label: "New"],
             children: []
           } =
             ~GPUI"""
             <GPUITemplateTest.Demo.Components.badge label="New" />
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
end
