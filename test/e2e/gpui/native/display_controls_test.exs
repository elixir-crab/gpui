defmodule GPUI.Native.DisplayControlsE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e

  defmodule ControlsView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[420px] h-[220px] gap-4 p-4 bg-slate-900">
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

  test "copy controls write to the display clipboard and progress renders natively" do
    title = "GPUI Display Controls E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: ControlsApp, args: %{title: title})
    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    native_window_id = Desktop.window_id!(title)
    Desktop.await_frame!(runtime, 1, native_window_id)
    Desktop.click!(native_window_id, 70, 30)

    assert_receive {:gpui, ^runtime, %GPUI.Runtime.Update{events: [%{event: "copied"}]}}

    Desktop.click!(native_window_id, 120, 80)
    Desktop.key!(native_window_id, "ctrl+v")

    Desktop.eventually(fn ->
      assert %{copied: true, value: "copied from display"} =
               GPUI.Runtime.snapshot(runtime).windows |> hd() |> get_in([:root, :assigns])
    end)
  end
end
