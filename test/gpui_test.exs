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

  test "rejects styles outside the generated native schema" do
    assert_raise ArgumentError, ~r/unsupported GPUI style/, fn ->
      div() |> style(:made_up, :value)
    end
  end

  test "validates window boundaries" do
    assert %GPUI.WindowSpec{} =
             GPUI.WindowSpec.validate!(%GPUI.WindowSpec{title: "Main", size: {800, 600}})

    assert_raise ArgumentError, ~r/positive integer/, fn ->
      GPUI.WindowSpec.validate!(%GPUI.WindowSpec{title: "Main", size: {0, 600}})
    end

    assert_raise ArgumentError, ~r/must implement render\/1/, fn ->
      GPUI.WindowSpec.validate!(%GPUI.WindowSpec{title: "Main", root: {String, %{}}})
    end
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
