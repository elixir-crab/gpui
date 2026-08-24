defmodule GPUI.Native.WindowChromeE2ETest do
  use GPUI.Test, desktop: true

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule ChromeView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[440px] h-[280px] bg-slate-900">
        <div
          id="chrome-drag"
          class="flex items-center w-full h-[48px] px-4 bg-slate-800"
          window_control="drag"
        >
          <text class="text-white">Content Chrome</text>
          <div class="flex grow" />
          <button id="chrome-close" class="w-[48px] h-[36px] text-white" window_control="close">
            Close
          </button>
        </div>
        <div class="flex grow p-5">
          <text class="text-white">Close requests: {assigns.close_requests}</text>
        </div>
      </div>
      """
    end

    @impl GPUI.View
    def handle_window_event(:close_request, _event, assigns),
      do: {:noreply, %{assigns | close_requests: assigns.close_requests + 1}}

    def handle_window_event(_event, _payload, assigns), do: {:noreply, assigns}
  end

  defmodule ChromeApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(440, 280)
           chrome(:content)
           root(ChromeView, close_requests: 0)
         end
       ]}
    end
  end

  test "content chrome delegates dragging and close requests to native window policy", %{
    desktop: desktop
  } do
    title = "GPUI Content Chrome E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: ChromeApp, args: %{title: title})

    window_id = Desktop.window!(desktop, title)
    before = Desktop.window_info!(desktop, window_id)

    if MapSet.member?(Desktop.capabilities(desktop), :window_drag) do
      Desktop.drag!(desktop, window_id, from: {220, 24}, to: {280, 64})

      Desktop.eventually(desktop, runtime, fn ->
        after_drag = Desktop.window_info!(desktop, window_id)
        assert after_drag.frame.x != before.frame.x or after_drag.frame.y != before.frame.y
      end)
    end

    after_drag = Desktop.window_info!(desktop, window_id)
    content_frame = Map.get(after_drag, :content_frame, after_drag.frame)
    close_x = content_frame.width - 24
    Desktop.click!(desktop, window_id, at: {close_x, 24})

    Desktop.eventually(desktop, runtime, fn -> assert %{close_requests: 1} = assigns(runtime) end)
    assert %{windows: [_window]} = GPUI.Runtime.snapshot(runtime)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
