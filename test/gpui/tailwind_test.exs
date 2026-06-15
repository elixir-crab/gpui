defmodule GPUITailwindTest do
  use ExUnit.Case, async: true

  test "normalizes a useful Tailwind subset" do
    assert %{
             style: [
               display: :flex,
               flex_direction: :column,
               align_items: :center,
               justify_content: :center,
               background: {:rgb, 0x404040},
               color: {:rgb, 0xFFFFFF},
               font_size: {:px, 20.0},
               width: {:px, 500.0},
               height: {:px, 500.0},
               gap: {:px, 12.0}
             ],
             unknown: []
           } =
             GPUI.Tailwind.normalize(
               "flex flex-col items-center justify-center bg-neutral-700 text-white text-xl size-[500px] gap-3"
             )
  end

  test "preserves unknown classes" do
    assert %{style: [display: :flex], unknown: ["hover:bg-blue-500"]} =
             GPUI.Tailwind.normalize("flex hover:bg-blue-500")
  end
end
