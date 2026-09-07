defmodule GPUI.Test.Native.SliderTest do
  use GPUI.Test, native: [size: {360, 100}]

  defmodule SliderView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <GPUI.UI.slider id="volume" label="Volume" class="w-[320px] h-6"
        value={assigns.value} min={0.0} max={100.0} step={5.0}
        disabled={assigns.disabled} phx-change="changed" phx-release="released" />
      """
    end
  end

  test "drag emits change and release and accepts a controlled rerender", %{ui: ui} do
    render(ui, SliderView, value: 25.0, disabled: false)
    settle(ui)
    %{x: x, y: y, width: width, height: height} = bounds(ui, "volume")
    drag(ui, {x + width * 0.25, y + height / 2}, {x + width * 0.75, y + height / 2})

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "changed", value: value}}}
                   when value > 25.0

    assert_receive {:gpui, ^ui, {:event, %{type: :release, event: "released", value: ^value}}}
    render(ui, SliderView, value: value, disabled: false)
    settle(ui)
    refute_receive {:gpui, ^ui, {:event, %{event: "changed"}}}
  end

  test "disabled sliders suppress drag events", %{ui: ui} do
    render(ui, SliderView, value: 25.0, disabled: true)
    settle(ui)
    %{x: x, y: y, width: width, height: height} = bounds(ui, "volume")
    drag(ui, {x + width * 0.25, y + height / 2}, {x + width * 0.75, y + height / 2})
    refute_receive {:gpui, ^ui, {:event, _}}
  end
end
