defmodule GPUI.Text.PresentationValueTest do
  use ExUnit.Case, async: true

  alias GPUI.Text.{BlockProjection, Decoration, InlineProjection, Position, Range}

  test "inline projection validates text and color at construction" do
    assert %InlineProjection{color: 0x123456} =
             InlineProjection.new(Position.new(0, 0), "hint", color: 0x123456)

    assert_raise ArgumentError, ~r/inline projection color/, fn ->
      InlineProjection.new(Position.new(0, 0), "hint", color: -1)
    end
  end

  test "block projection validates presentation bounds at construction" do
    assert %BlockProjection{placement: :before, height: 48} =
             BlockProjection.new(0, "notice", placement: :before, height: 48)

    assert_raise ArgumentError, ~r/block projection height/, fn ->
      BlockProjection.new(0, "notice", height: 0)
    end
  end

  test "decoration validates colors and underline style at construction" do
    range = Range.caret(Position.new(0, 0))

    assert %Decoration{underline_style: :wavy} =
             Decoration.new(range, underline: 0xFF0000, underline_style: :wavy)

    assert_raise ArgumentError, ~r/underline_style/, fn ->
      Decoration.new(range, underline_style: :double)
    end
  end
end
