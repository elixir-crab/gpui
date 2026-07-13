defmodule GPUI.Native.InteractivityE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule InteractiveView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[400px] h-[240px] p-4 gap-4 bg-slate-900">
        <button class="w-[160px] h-[48px] bg-blue-600 text-white" phx-click="increment">
          Increment
        </button>
        <input class="w-[240px] h-[48px]" value={assigns.value} phx-change="change" phx-keydown="keydown" phx-keyup="keyup" />
        <text class="text-white">Count: {assigns.count}; Value: {assigns.value}</text>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("increment", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}

    def handle_event("change", %{value: value}, assigns),
      do: {:noreply, %{assigns | value: value}}

    def handle_event("keydown", %{value: key}, assigns),
      do: {:noreply, %{assigns | keydowns: [key | assigns.keydowns]}}

    def handle_event("keyup", %{value: key}, assigns),
      do: {:noreply, %{assigns | keyups: [key | assigns.keyups]}}
  end

  defmodule InteractiveApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(400, 240)
           root(InteractiveView, count: 0, value: "", keydowns: [], keyups: [])
         end
       ]}
    end
  end

  test "real pointer and keyboard input reaches the Elixir view and rerenders" do
    title = "GPUI Interactivity E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: InteractiveApp, args: %{title: title})
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)

    Desktop.click!(window_id, 80, 40)

    Desktop.eventually(fn ->
      assert %{count: 1} = assigns(runtime)
    end)

    Desktop.click!(window_id, 100, 100)
    Desktop.type!(window_id, "abc")

    Desktop.eventually(fn ->
      assert %{value: "abc", keydowns: keydowns, keyups: keyups} = assigns(runtime)
      assert [_, _, _ | _] = keydowns
      assert [_, _, _ | _] = keyups
    end)

    Desktop.close_window!(window_id)

    Desktop.eventually(fn ->
      assert %{windows: []} = GPUI.Runtime.snapshot(runtime)
    end)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
