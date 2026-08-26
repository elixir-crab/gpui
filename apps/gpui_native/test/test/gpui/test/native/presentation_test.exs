defmodule GPUI.Test.Native.PresentationTest do
  use GPUI.Test, native: [size: {360, 240}]

  defmodule View do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(_assigns) do
      ~GPUI"""
      <div class="flex flex-col gap-2 w-full h-full">
        <UI.paint
          id="paint-surface"
          commands={[
            %{type: :rect, x: 0, y: 0, width: 0, height: 0, color: 0xFFFFFFFF},
            %{type: :line, x1: -20, y1: 20, x2: 180, y2: 20, width: 2, color: 0xFFFFFFFF}
          ]}
          class="w-[120px] h-[40px] overflow-hidden"
        />

        <UI.frost
          id="opaque-frost"
          fallback="translucent"
          opacity={0.25}
          reduced_transparency={true}
          class="w-[140px] h-[36px]"
        >
          <text>Opaque fallback</text>
        </UI.frost>

        <UI.edge_fade
          id="bounded-fades"
          edges={[:top, :bottom]}
          size={16}
          class="w-[160px] h-[80px]"
        >
          <scroll id="fade-scroll" class="w-full h-full">
            <text>Scrolling remains an explicit child.</text>
          </scroll>
        </UI.edge_fade>
      </div>
      """
    end
  end

  test "presentation surfaces keep their declared layout bounds", %{ui: ui} do
    render(ui, View, %{})

    assert %{width: 120.0, height: 40.0} = bounds(ui, "paint-surface")
    assert %{width: 140.0, height: 36.0} = bounds(ui, "opaque-frost")
    assert %{width: 160.0, height: 80.0} = bounds(ui, "bounded-fades")
  end
end
