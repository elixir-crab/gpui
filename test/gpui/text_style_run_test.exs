defmodule GPUI.Text.StyleRunTest do
  use ExUnit.Case, async: true

  alias GPUI.Text.Position
  alias GPUI.Text.Range
  alias GPUI.Text.StyleRun

  test "constructs neutral shaping facts" do
    range = Range.new(Position.new(0, 1), Position.new(0, 3))

    assert %StyleRun{
             range: ^range,
             color: 0xF97316,
             font_weight: :semibold,
             font_style: :italic
           } = StyleRun.new(range, color: 0xF97316, font_weight: :semibold, font_style: :italic)
  end

  test "requires a valid shaping property" do
    range = Range.new(Position.new(0, 0), Position.new(0, 1))

    assert_raise ArgumentError, ~r/must set/, fn -> StyleRun.new(range) end
    assert_raise ArgumentError, ~r/color/, fn -> StyleRun.new(range, color: 0x1000000) end

    assert_raise ArgumentError, ~r/font_weight/, fn ->
      StyleRun.new(range, font_weight: :heavy)
    end

    assert_raise ArgumentError, ~r/font_style/, fn ->
      StyleRun.new(range, font_style: :slanted)
    end
  end
end
