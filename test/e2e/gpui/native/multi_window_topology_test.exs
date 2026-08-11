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
  end

  defmodule App do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window "main", title do
           size(480, 320)
           root(View, label: "Main")
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

    details = %GPUI.WindowSpec{
      key: "details",
      title: details_title,
      size: {420, 280},
      root: {View, %{label: "Details"}}
    }

    assert {:ok, 2, %{windows: [_, %{key: "details"}]}} =
             GPUI.Runtime.open_window(runtime, details)

    details_native = Desktop.window_id!(details_title)
    Desktop.await_frame!(runtime, 2, details_native)

    assert {:ok, %{windows: [%{key: "main"}]}} = GPUI.Runtime.close_window(runtime, "details")

    Desktop.eventually(fn ->
      assert {:error, :window_not_found} = GPUI.Runtime.frame_token(runtime, 2)
    end)

    assert {:ok, 3, %{windows: [_, %{id: 3, key: "details"}]}} =
             GPUI.Runtime.open_window(runtime, details)

    reopened_native = Desktop.window_id!(details_title)
    Desktop.await_frame!(runtime, 3, reopened_native)
    assert reopened_native != details_native
    assert Desktop.window_id!(main_title) == main_native
  end
end
