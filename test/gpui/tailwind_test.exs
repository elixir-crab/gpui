defmodule GPUI.TailwindTest do
  use ExUnit.Case, async: true

  test "programmatic UI components normalize classes before serialization" do
    payload =
      GPUI.UI.tree_item(%{
        id: "file",
        class: "flex items-center px-2 truncate cursor-pointer unknown-class",
        style: [color: {:rgb, 0xFFFFFF}],
        children: ["long filename"]
      })
      |> GPUI.Element.to_payload()

    assert payload.attrs.class == "unknown-class"

    assert payload.attrs.style == [
             display: :flex,
             align_items: :center,
             padding_x: [:px, 8.0],
             truncate: true,
             cursor: :pointer,
             color: [:rgb, 0xFFFFFF]
           ]
  end

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

  test "normalizes positioned layout and explicit insets" do
    assert %{
             style: [
               position: :relative,
               inset_x: {:fraction, 0.5},
               top: {:px, 8.0},
               right: :auto,
               bottom: {:px, 12.0},
               left: {:px, 18.0},
               margin_top: {:px, 4.0}
             ],
             unknown: []
           } =
             GPUI.Tailwind.normalize(
               "relative inset-x-1/2 top-2 right-auto bottom-3 left-[18px] mt-1"
             )

    assert %{style: style, unknown: []} =
             GPUI.Tailwind.normalize("absolute inset-0 -top-2 left-[-6px]")

    assert style == [
             position: :absolute,
             inset: {:px, 0},
             top: {:px, -8.0},
             left: {:px, -6.0}
           ]
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

  test "normalizes flex basis using lengths and auto" do
    assert %{style: style, unknown: []} =
             GPUI.Tailwind.normalize("basis-0 w-24 h-60 min-w-0 max-h-64")

    assert Keyword.fetch!(style, :flex_basis) == {:px, 0.0}
    assert Keyword.fetch!(style, :width) == {:px, 96.0}
    assert Keyword.fetch!(style, :height) == {:px, 240.0}
    assert Keyword.fetch!(style, :min_width) == {:px, 0.0}
    assert Keyword.fetch!(style, :max_height) == {:px, 256.0}

    for {class, expected} <- [
          {"basis-auto", :auto},
          {"basis-full", :full},
          {"basis-1/2", {:fraction, 0.5}},
          {"basis-[240px]", {:px, 240.0}}
        ] do
      assert %{style: [flex_basis: ^expected], unknown: []} = GPUI.Tailwind.normalize(class)
    end
  end

  test "normalizes clipping and dense text behavior" do
    assert %{
             style: [
               overflow: :hidden,
               white_space: :nowrap,
               text_overflow: :ellipsis,
               text_align: :right,
               truncate: true
             ],
             unknown: []
           } =
             GPUI.Tailwind.normalize(
               "overflow-hidden whitespace-nowrap text-ellipsis text-right truncate"
             )

    assert %{style: [white_space: :normal, text_align: :left], unknown: ["text-clip"]} =
             GPUI.Tailwind.normalize("whitespace-normal text-left text-clip")
  end

  test "normalizes native cursor behavior" do
    for {class, expected} <- [
          {"cursor-default", :default},
          {"cursor-pointer", :pointer},
          {"cursor-text", :text},
          {"cursor-move", :move},
          {"cursor-not-allowed", :not_allowed}
        ] do
      assert %{style: [cursor: ^expected], unknown: []} = GPUI.Tailwind.normalize(class)
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

  test "normalizes the complete pinned Tailwind palette" do
    assert GPUI.Tailwind.Palette.tailwind_version() == "3.4.17"
    assert map_size(GPUI.Tailwind.Palette.colors()) == 245

    for family <-
          ~w(slate gray zinc neutral stone red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple fuchsia pink rose),
        shade <- ~w(50 100 200 300 400 500 600 700 800 900 950) do
      assert {:ok, {:rgb, rgb}} = GPUI.Tailwind.Palette.fetch("#{family}-#{shade}")
      assert rgb in 0..0xFFFFFF
    end

    assert GPUI.Tailwind.Palette.fetch!("slate-950") == {:rgb, 0x020617}
    assert GPUI.Tailwind.Palette.fetch!("white") == {:rgb, 0xFFFFFF}
    assert GPUI.Tailwind.Palette.fetch!("transparent") == {:rgba, 0x00000000}
  end

  test "normalizes named colors with deterministic alpha modifiers" do
    assert %{style: style, unknown: []} =
             GPUI.Tailwind.normalize("bg-black/40 text-slate-300/70 border-white/5")

    assert style == [
             background: {:rgba, 0x00000066},
             color: {:rgba, 0xCBD5E1B3},
             border_color: {:rgba, 0xFFFFFF0D}
           ]
  end

  test "normalizes bounded arbitrary RGB and RGBA colors" do
    assert %{style: style, unknown: []} =
             GPUI.Tailwind.normalize("bg-[#abc] text-[#abcd] border-[#0f172a] bg-[#0f172acc]/80")

    assert style == [
             color: {:rgba, 0xAABBCCDD},
             border_color: {:rgb, 0x0F172A},
             background: {:rgba, 0x0F172AA3}
           ]
  end

  test "preserves malformed color classes" do
    classes =
      "bg-red-500/101 text-slate-300/-1 border-white/foo bg-[#12] text-[#xyz] " <>
        "border-[#0f172a]extra bg-not-a-color"

    assert %{style: [], unknown: unknown} = GPUI.Tailwind.normalize(classes)
    assert unknown == String.split(classes)
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
