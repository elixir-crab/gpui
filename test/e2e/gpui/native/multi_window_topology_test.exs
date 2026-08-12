defmodule GPUI.Native.MultiWindowTopologyE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e

  defmodule View do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex grow w-full h-full p-6 bg-slate-900 text-white">
        <text>{assigns.label}</text>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("open-details", _event, assigns) do
      details = %GPUI.WindowSpec{
        key: "details",
        title: assigns.details_title,
        size: {420, 280},
        root: {View, %{label: "Details", status: "ready", details_title: assigns.details_title}}
      }

      {:open_window, details, %{assigns | status: "opened"}}
    end

    def handle_event("close-details", _event, assigns),
      do: {:close_window, "details", %{assigns | status: "closed"}}
  end

  defmodule App do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window "main", title do
           size(480, 320)

           root(View,
             label: "Main",
             status: "ready",
             details_title: "GPUI Details #{System.unique_integer([:positive])}"
           )
         end
       ]}
    end
  end

  test "keyed windows open, close, and reopen with monotonic native IDs" do
    suffix = System.unique_integer([:positive])
    main_title = "GPUI Main #{suffix}"
    details_title = "GPUI Details #{suffix}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: App, args: %{title: main_title})
    on_exit(fn -> Desktop.stop_process(runtime) end)

    main_native = Desktop.window_id!(main_title)
    Desktop.await_frame!(runtime, 1, main_native)

    %{windows: [%{root: %{assigns: %{details_title: details_title}}}]} =
      GPUI.Runtime.snapshot(runtime)

    {_event, %{windows: [_, %{id: 2, key: "details"}]}} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "open-details"
      })

    details_native = Desktop.window_id!(details_title)
    Desktop.await_frame!(runtime, 2, details_native)

    {_event, %{windows: [%{key: "main"}]}} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "close-details"
      })

    Desktop.eventually(fn ->
      assert {:error, :window_not_found} = GPUI.Runtime.frame_token(runtime, 2)
    end)

    {_event, %{windows: [_, %{id: 3, key: "details"}]}} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "open-details"
      })

    reopened_native = Desktop.window_id!(details_title)
    Desktop.await_frame!(runtime, 3, reopened_native)
    assert reopened_native != details_native
    assert Desktop.window_id!(main_title) == main_native
  end
end
