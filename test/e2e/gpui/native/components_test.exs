defmodule GPUI.Native.ComponentsE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule ComponentsView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[360px] h-[220px] p-4 gap-4 bg-slate-900">
        <GPUI.UI.button
          id="component-button"
          label="Increment"
          variant="primary"
          phx-click="increment"
        />
        <GPUI.UI.checkbox
          id="component-checkbox"
          label="Enabled"
          checked={assigns.enabled}
          phx-change="toggle"
        />
        <text class="text-white">Count: {assigns.count}; Enabled: {assigns.enabled}</text>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("increment", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}

    def handle_event("toggle", %{value: enabled}, assigns) when is_boolean(enabled),
      do: {:noreply, %{assigns | enabled: enabled}}
  end

  defmodule ComponentsApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(360, 220)
           root(ComponentsView, count: 0, enabled: false)
         end
       ]}
    end
  end

  test "native GPUI components emit controlled Elixir events and rerender" do
    title = "GPUI Components E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: ComponentsApp, args: %{title: title})
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)
    Desktop.click!(window_id, 80, 32)

    Desktop.eventually(fn ->
      assert %{count: 1, enabled: false} = assigns(runtime)
    end)

    Desktop.click!(window_id, 32, 72)

    Desktop.eventually(fn ->
      assert %{count: 1, enabled: true} = assigns(runtime)
    end)

    Desktop.click!(window_id, 32, 72)

    Desktop.eventually(fn ->
      assert %{count: 1, enabled: false} = assigns(runtime)
    end)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
