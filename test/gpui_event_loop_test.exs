defmodule GPUIEventLoopTest do
  use ExUnit.Case, async: false

  defmodule CounterView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col items-center gap-3">
        <text class="text-xl">Count: {assigns.count}</text>
        <button phx-click="inc">+</button>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("inc", _event, assigns) do
      {:noreply, %{assigns | count: assigns.count + 1}}
    end
  end

  defmodule CounterApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok, %{},
       [
         window "Counter" do
           size(300, 200)
           root(CounterView, count: 0)
         end
       ]}
    end
  end

  test "native click events update view assigns and re-render" do
    {:ok, pid} = GPUI.Runtime.start_link(app: CounterApp, backend: :native)
    [window] = GPUI.Runtime.windows(pid)

    assert GPUI.Element.to_payload(CounterView.render(%{count: 0})).children
           |> hd()
           |> Map.fetch!(:children) == ["Count: ", 0]

    {:ok, :ok} =
      GPUI.Native.emit_test_event(:sys.get_state(pid).native, %{
        window_id: window.id,
        event: "inc"
      })

    handled = GPUI.Runtime.drain_events(pid)
    assert %{type: :click, event: "inc", window_id: 1} in handled

    [updated] = GPUI.Runtime.windows(pid)
    assert {_module, %{count: 1}} = updated.root

    payload = GPUI.Runtime.window_payload(updated)
    assert get_in(payload, [:root, :tree, :children, Access.at(0), :children]) == ["Count: ", 1]

    assert %{op: :native_event, payload: %{type: :window_updated, window_id: 1}} in GPUI.Runtime.host_messages(
             pid
           )

    GenServer.stop(pid)
  end
end
