defmodule GPUI.Native.TextStyleRunE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

  alias GPUI.Text.Buffer
  alias GPUI.Text.Position
  alias GPUI.Text.Range
  alias GPUI.Text.StyleRun

  @moduletag :e2e

  defmodule View do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <text_surface
        id="styled-document"
        class="w-full h-full p-6 bg-slate-900 text-white text-lg"
        buffer={assigns.buffer}
        style_runs={assigns.style_runs}
      />
      """
    end
  end

  defmodule App do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title, buffer: buffer, style_runs: style_runs}) do
      {:ok,
       [
         window title do
           size(640, 320)
           root(View, buffer: buffer, style_runs: style_runs)
         end
       ]}
    end
  end

  test "foreground style runs render through the editable native shaping path", %{
    desktop: desktop
  } do
    {:ok, buffer} = Buffer.new("orange weighted text\nplain text")
    range = Range.new(Position.new(0, 0), Position.new(0, 15))
    run = StyleRun.new(range, color: 0xF97316, font_weight: :bold, font_style: :italic)
    title = "GPUI Style Run E2E #{System.unique_integer([:positive])}"

    runtime =
      start_runtime!(desktop,
        app: App,
        args: %{title: title, buffer: buffer, style_runs: [run]}
      )

    native_window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, native_window)

    assert %{windows: [%{root: %{assigns: %{style_runs: [^run]}}}]} =
             GPUI.Runtime.snapshot(runtime)
  end
end
