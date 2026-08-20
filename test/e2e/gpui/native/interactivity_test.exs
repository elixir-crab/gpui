defmodule GPUI.Native.InteractivityE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule InteractiveView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[420px] h-[360px] p-4 gap-4 bg-slate-900">
        <button class="w-[160px] h-[48px] bg-blue-600 text-white" phx-click="increment">
          Increment
        </button>
        <text_input class="w-[240px] h-[48px]" value={assigns.primary} phx-change="change-primary" phx-keydown="keydown" phx-keyup="keyup" />
        <text_input class="w-[240px] h-[48px]" value={assigns.secondary} phx-change="change-secondary" />
        <button class="w-[160px] h-[48px] bg-green-600 text-white" phx-click="reset">
          Reset
        </button>
        <text class="text-white">Count: {assigns.count}; Primary: {assigns.primary}; Secondary: {assigns.secondary}</text>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("increment", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}

    def handle_event("change-primary", %{value: value}, assigns),
      do: {:noreply, %{assigns | primary: value}}

    def handle_event("change-secondary", %{value: value}, assigns),
      do: {:noreply, %{assigns | secondary: value}}

    def handle_event("reset", _event, assigns),
      do: {:noreply, %{assigns | primary: "server"}}

    def handle_event("select_all_conflict", _event, assigns),
      do: {:noreply, %{assigns | command_conflicts: assigns.command_conflicts + 1}}

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
           size(420, 360)
           shortcut("increment", "primary-i")
           shortcut("select_all_conflict", "primary-a")

           root(InteractiveView,
             count: 0,
             command_conflicts: 0,
             primary: "",
             secondary: "",
             keydowns: [],
             keyups: []
           )
         end
       ]}
    end
  end

  test "real pointer and keyboard input reaches the Elixir view and rerenders" do
    title = "GPUI Interactivity E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: InteractiveApp, args: %{title: title})
    :ok = GPUI.Runtime.subscribe(runtime)
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)

    Desktop.click!(window_id, 80, 40)

    Desktop.eventually(fn ->
      assert %{count: 1} = assigns(runtime)
    end)

    Desktop.click!(window_id, 100, 100)
    Desktop.type!(window_id, "abc")
    Desktop.key!(window_id, "BackSpace")

    Desktop.eventually(fn ->
      assert %{primary: "ab", keydowns: keydowns, keyups: keyups} = assigns(runtime)
      assert [_, _, _ | _] = keydowns
      assert [_, _, _ | _] = keyups
    end)

    Desktop.key!(window_id, "super+a")
    Desktop.key!(window_id, "super+c")
    Desktop.click!(window_id, 100, 164)
    Desktop.key!(window_id, "super+v")
    Desktop.type!(window_id, "z")

    Desktop.eventually(fn ->
      assert %{primary: "ab", secondary: "abz"} = assigns(runtime)
    end)

    Desktop.click!(window_id, 80, 228)

    Desktop.eventually(fn ->
      assert %{primary: "server", secondary: "abz"} = assigns(runtime)
    end)

    Desktop.click!(window_id, 100, 100)
    Desktop.key!(window_id, "End")
    Desktop.type!(window_id, "!")

    Desktop.eventually(fn ->
      assert %{primary: "server!", secondary: "abz"} = assigns(runtime)
    end)

    Desktop.key!(window_id, "ctrl+a")
    Desktop.type!(window_id, "selected")

    Desktop.eventually(fn ->
      assert %{primary: "server!selected", command_conflicts: 0} = assigns(runtime)
    end)

    Desktop.key!(window_id, "ctrl+i")
    Desktop.eventually(fn -> assert %{count: 2} = assigns(runtime) end)

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
