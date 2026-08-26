defmodule GPUI.ColorTest do
  use ExUnit.Case, async: true

  import GPUI.Color, only: [sigil_RGB: 2, sigil_RGBA: 2]

  test "expands short and parses long RGB literals" do
    assert ~RGB"abc" == {:rgb, 0xAABBCC}
    assert ~RGB"0f172a" == {:rgb, 0x0F172A}
    assert ~RGB"F8FAFC" == {:rgb, 0xF8FAFC}
  end

  test "expands short and parses long RGBA literals" do
    assert ~RGBA"abcd" == {:rgba, 0xAABBCCDD}
    assert ~RGBA"0f172acc" == {:rgba, 0x0F172ACC}
    assert ~RGBA"FFFFFF1A" == {:rgba, 0xFFFFFF1A}
  end

  test "views import both color sigils" do
    defmodule ColorView do
      use GPUI.View

      def colors do
        {~RGB"0f172a", ~RGBA"ffffff1a"}
      end

      @impl GPUI.View
      def render(_assigns) do
        ~GPUI"""
        <div style={[background: ~RGB"0f172a", border_color: ~RGBA"ffffff1a"]} />
        """
      end
    end

    assert ColorView.colors() == {{:rgb, 0x0F172A}, {:rgba, 0xFFFFFF1A}}

    assert %{attrs: %{style: style}} = ColorView.render(%{}) |> GPUI.Element.to_payload()
    assert style[:background] == [:rgb, 0x0F172A]
    assert style[:border_color] == [:rgba, 0xFFFFFF1A]
  end

  test "rejects malformed literals at compile time" do
    for expression <- [
          ~s(import GPUI.Color; ~RGB"12"),
          ~s(import GPUI.Color; ~RGB"gggggg"),
          ~s(import GPUI.Color; ~RGBA"ffffff"),
          ~s(import GPUI.Color; ~RGBA"1234567z"),
          ~s(import GPUI.Color; ~RGB"ffffff"u)
        ] do
      assert_raise CompileError, fn -> Code.compile_string(expression) end
    end
  end
end
