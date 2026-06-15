defmodule GPUI.Test do
  use ExUnit.Case, async: true

  import Kernel, except: [div: 2]
  import GPUI

  test "builds block-style element trees" do
    element =
      div(class: "flex") do
        text("Hello")
      end

    assert %GPUI.Element{
             type: :div,
             attrs: [class: "flex"],
             children: [%GPUI.Element{type: :text, children: ["Hello"]}]
           } = element
  end

  test "builds pipe-style element trees" do
    assert %GPUI.Element{attrs: [style: style], children: ["Hello"]} =
             div()
             |> flex()
             |> flex_col()
             |> items_center()
             |> justify_center()
             |> bg(rgb(0x505050))
             |> size(px(500))
             |> child("Hello")

    assert style[:display] == :flex
    assert style[:flex_direction] == :column
    assert style[:align_items] == :center
    assert style[:justify_content] == :center
    assert style[:background] == {:rgb, 0x505050}
    assert style[:width] == {:px, 500.0}
    assert style[:height] == {:px, 500.0}
  end
end
