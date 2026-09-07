defmodule GPUI.Test.Native.SplitTest do
  use GPUI.Test, native: [size: {800, 480}]

  defmodule View do
    use GPUI.View
    alias GPUI.{Element, UI}

    @impl GPUI.View
    def render(assigns) do
      UI.split(%{
        :"phx-change" => "split_resized",
        id: "native-split",
        class: "w-full h-full",
        sizes: assigns.sizes,
        min_sizes: [140, 240],
        resize_request: assigns.resize_request,
        children: [
          %Element{
            type: :div,
            attrs: [id: "first-pane", class: "w-full h-full"],
            children: ["First"]
          },
          %Element{
            type: :div,
            attrs: [id: "second-pane", class: "w-full h-full"],
            children: ["Second"]
          }
        ]
      })
    end
  end

  test "divider drag respects minimum sizes and survives controlled rerenders", %{ui: ui} do
    render(ui, View, sizes: [260, 540], resize_request: 0)
    settle(ui)
    drag(ui, {260, 200}, {360, 200})

    assert_receive {:gpui, ^ui,
                    {:event, %{event: "split_resized", value: [first, second] = sizes}}}
                   when first > 300 and second >= 240

    render(ui, View, sizes: sizes, resize_request: 0)
    settle(ui)
    assert %{width: width} = bounds(ui, "first-pane")
    assert_in_delta width, first, 5
    drag(ui, {first, 200}, {790, 200})

    assert_receive {:gpui, ^ui, {:event, %{event: "split_resized", value: [left, right]}}}
                   when left >= 140 and right >= 240
  end
end
