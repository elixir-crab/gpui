defmodule GPUI.Native.DisplayControlsE2ETest do
  use GPUI.Test, desktop: true

  @moduletag :e2e

  defmodule ControlsView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[420px] h-[220px] gap-4 p-4 bg-white text-slate-900">
        <UI.button
          id="copy-value"
          label="Copy value"
          clipboard_text="copied from display"
          phx-clipboard-write="copied"
        />
        <UI.input id="paste-target" label="Paste target" value={assigns.value} phx-change="value_changed" />
        <UI.progress id="deterministic-progress" label="Importing" value={40} max={100} />
        <UI.progress id="indeterminate-progress" label="Waiting" indeterminate={true} />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("copied", _event, assigns), do: {:noreply, %{assigns | copied: true}}

    def handle_event("value_changed", %{value: value}, assigns),
      do: {:noreply, %{assigns | value: value}}
  end

  defmodule ControlsApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(420, 220)
           root(ControlsView, value: "", copied: false)
         end
       ]}
    end
  end

  test "desktop renders native display controls", %{desktop: desktop} do
    title = "GPUI Display Controls E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: ControlsApp, args: %{title: title})
    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{windows: [%{root: %{assigns: %{copied: false}}}]} = GPUI.Runtime.snapshot(runtime)
    assert Process.alive?(runtime)
  end
end
