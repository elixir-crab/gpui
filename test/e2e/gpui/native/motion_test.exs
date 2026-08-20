defmodule GPUI.Native.MotionE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule MotionView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[420px] h-[280px] p-5 gap-4 bg-slate-900">
        <button
          id="replay"
          class="w-[160px] h-[48px] bg-blue-600 text-white"
          phx-click="replay"
        >
          Replay motion
        </button>

        <button
          id="motion-card"
          class="flex flex-col w-[300px] h-[120px] p-4 gap-2 bg-green-600 text-white"
          phx-click="activate"
          accessibility_label="Animated action"
          motion_request={assigns.motion_request}
          motion_duration={180}
          motion_easing="linear"
          motion_from_opacity={0.0}
          motion_from_y={16}
        >
          <text>Animated action</text>
          <text>Request {assigns.motion_request}; activations {assigns.activations}</text>
        </button>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("replay", _event, assigns),
      do: {:noreply, %{assigns | motion_request: assigns.motion_request + 1}}

    def handle_event("activate", _event, assigns),
      do: {:noreply, %{assigns | activations: assigns.activations + 1}}
  end

  defmodule MotionApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(420, 280)
           root(MotionView, motion_request: 1, activations: 0)
         end
       ]}
    end
  end

  test "animated semantic containers keep native pointer and keyboard activation" do
    title = "GPUI Motion E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: MotionApp, args: %{title: title})
    :ok = GPUI.Runtime.subscribe(runtime)
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)

    # Let the entrance settle, then prove the animated element retained its hitbox.
    Process.sleep(250)
    Desktop.click!(window_id, 150, 130)
    Desktop.eventually(fn -> assert %{activations: 1} = assigns(runtime) end)

    Desktop.click!(window_id, 80, 40)
    Desktop.eventually(fn -> assert %{motion_request: 2} = assigns(runtime) end)

    # A changed token restarts presentation without changing the destination tree.
    assert %{attrs: %{id: "motion-card", motion_request: 2}, children: children} =
             motion_card(runtime)

    assert Enum.any?(children, &match?(%{children: ["Animated action"]}, &1))

    Process.sleep(250)
    Desktop.click!(window_id, 150, 130)
    Desktop.eventually(fn -> assert %{activations: 2} = assigns(runtime) end)

    Desktop.click!(window_id, 150, 130)
    Desktop.key!(window_id, "Return")
    Desktop.eventually(fn -> assert %{activations: 3} = assigns(runtime) end)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end

  defp motion_card(runtime) do
    %{windows: [%{root: root}]} = GPUI.Runtime.snapshot(runtime)
    find_node(root.tree, "motion-card")
  end

  defp find_node(%{attrs: %{id: id}} = node, id), do: node

  defp find_node(%{children: children}, id) do
    Enum.find_value(children, &find_node(&1, id))
  end

  defp find_node(_node, _id), do: nil
end
