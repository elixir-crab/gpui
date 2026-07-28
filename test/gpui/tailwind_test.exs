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

  test "normalizes full and fractional dimensions as relative native lengths" do
    assert %{
             style: [
               width: :full,
               height: :full,
               min_width: {:fraction, 0.5},
               max_height: {:fraction, 0.6666666666666666}
             ],
             unknown: []
           } = GPUI.Tailwind.normalize("w-full h-full min-w-1/2 max-h-2/3")
  end

  test "normalizes flex shorthand with native GPUI semantics" do
    assert %{
             style: [flex: :one, display: :flex],
             unknown: []
           } = GPUI.Tailwind.normalize("flex-1 flex")

    for {class, value} <- [
          {"flex-auto", :auto},
          {"flex-initial", :initial},
          {"flex-none", :none}
        ] do
      assert %{style: [flex: ^value], unknown: []} = GPUI.Tailwind.normalize(class)
    end
  end

  test "normalizes numeric scales and safe arbitrary values" do
    assert %{
             style: [
               gap: {:px, 6.0},
               padding: {:px, 28.0},
               width: {:px, 500.0},
               height: {:fraction, 0.5},
               font_size: {:px, 13.0},
               line_height: {:px, 18.0},
               opacity: 0.65,
               background: {:rgb, 0x101828},
               color: {:rgb, 0x94A3B8},
               border_radius: {:px, 5.0}
             ],
             unknown: []
           } =
             GPUI.Tailwind.normalize(
               "gap-1.5 p-7 w-[500px] h-[50%] text-[13px] leading-[18px] " <>
                 "opacity-[0.65] bg-[#101828] text-[#94a3b8] rounded-[5px]"
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

  test "every normalized style is supported by the native schema" do
    classes =
      "flex block grid hidden flex-col-reverse flex-wrap grow shrink-0 items-baseline " <>
        "justify-evenly font-bold leading-normal opacity-50 p-2 px-3 mt-1 w-full h-full " <>
        "min-w-6 max-h-8 border border-blue-500 rounded-lg bg-slate-900 text-white"

    assert %{style: styles} = GPUI.Tailwind.normalize(classes)
    assert Enum.all?(Keyword.keys(styles), &(&1 in GPUI.Schema.styles()))
  end

  test "preserves unsupported classes exactly" do
    assert %{
             style: [display: :flex],
             unknown: ["hover:bg-blue-500", "w-[calc(100%-1rem)]", "mx-auto"]
           } = GPUI.Tailwind.normalize("flex hover:bg-blue-500 w-[calc(100%-1rem)] mx-auto")
  end
end
