defmodule GPUI.TailwindTest do
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

  test "normalizes colors used by the counter example" do
    assert %{style: [background: {:rgb, 0x0F172A}], unknown: []} =
             GPUI.Tailwind.normalize("bg-slate-900")

    assert %{style: [background: {:rgb, 0x2563EB}], unknown: []} =
             GPUI.Tailwind.normalize("bg-blue-600")
  end

  test "normalizes expanded layout, typography, and box styles" do
    assert %{style: style, unknown: []} =
             GPUI.Tailwind.normalize(
               "grid flex-row-reverse flex-wrap grow shrink-0 items-stretch justify-between " <>
                 "font-semibold leading-tight opacity-75 px-4 mb-2 min-w-10 max-h-12 " <>
                 "border border-red-500"
             )

    assert style == [
             display: :grid,
             flex_direction: :row_reverse,
             flex_wrap: :wrap,
             flex_grow: 1.0,
             flex_shrink: 0.0,
             align_items: :stretch,
             justify_content: :between,
             font_weight: :semibold,
             line_height: {:px, 20.0},
             opacity: 0.75,
             padding_x: {:px, 16.0},
             margin_bottom: {:px, 8.0},
             min_width: {:px, 40.0},
             max_height: {:px, 48.0},
             border_width: {:px, 1.0},
             border_color: {:rgb, 0xEF4444}
           ]
  end

  test "preserves unknown classes" do
    assert %{style: [display: :flex], unknown: ["hover:bg-blue-500"]} =
             GPUI.Tailwind.normalize("flex hover:bg-blue-500")
  end
end
