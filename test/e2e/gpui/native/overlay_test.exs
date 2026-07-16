defmodule GPUI.Native.OverlayE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule OverlayView do
    use GPUI.View

    alias GPUI.UI
    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[420px] h-[240px] p-4 bg-slate-900">
        <Overlay.popover
          id="account-popover"
          open={assigns.open}
          phx-change="open_changed"
        >
          <:trigger>
            <UI.button id="account-trigger" label="Account" />
          </:trigger>
          <:content>
            <div class="w-[180px] p-2">
              <text>Account settings</text>
            </div>
          </:content>
        </Overlay.popover>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("open_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | open: open}}
  end

  defmodule OverlayApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(420, 240)
           root(OverlayView, open: false)
         end
       ]}
    end
  end

  test "controlled popovers dismiss with Escape and outside clicks" do
    title = "GPUI Overlay E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: OverlayApp, args: %{title: title})
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)
    Desktop.click!(window_id, 50, 28)
    Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)

    Desktop.key!(window_id, "Escape")
    Desktop.eventually(fn -> assert %{open: false} = assigns(runtime) end)

    Desktop.key!(window_id, "space")
    Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)
    Desktop.key!(window_id, "Escape")
    Desktop.eventually(fn -> assert %{open: false} = assigns(runtime) end)

    Desktop.click!(window_id, 50, 28)
    Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)

    Desktop.click!(window_id, 360, 190)
    Desktop.eventually(fn -> assert %{open: false} = assigns(runtime) end)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
