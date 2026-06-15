defmodule GPUI.Runtime.EventLoopTest do
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

  defmodule ResourceImageView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <img raster={assigns.logo} />
      """
    end
  end

  defmodule ResourceImageApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok, %{},
       [
         window("Resource Image",
           do: root(ResourceImageView, logo: GPUI.ResourceRef.new("logo", :raster))
         )
       ]}
    end
  end

  defmodule InputView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div>
        <input value={assigns.name} phx-change="rename" />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("rename", %{value: value}, assigns) do
      {:noreply, %{assigns | name: value}}
    end
  end

  defmodule InputApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok, %{},
       [
         window "Input" do
           root(InputView, name: "old")
         end
       ]}
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
      GPUI.Runtime.emit_test_event(pid, %{
        window_id: window.id,
        event: "inc"
      })

    handled = GPUI.Runtime.drain_events(pid)
    assert %{type: :click, event: "inc", window_id: 1} in handled

    [updated] = GPUI.Runtime.windows(pid)
    assert {_module, %{count: 1}} = updated.root

    payload = GPUI.Runtime.window_payload(updated)
    assert get_in(payload, [:root, :tree, :children, Access.at(0), :children]) == ["Count: ", 1]
    assert get_in(payload, [:root, :tree, :children, Access.at(1), :attrs, :"phx-click"]) == "inc"

    assert %{op: :backend_event, payload: %{type: :window_updated, window_id: 1}} in GPUI.Runtime.host_messages(
             pid
           )

    GenServer.stop(pid)
  end

  test "runtime resolves resource refs after resources are stored" do
    {:ok, pid} = GPUI.Runtime.start_link(app: ResourceImageApp, backend: :data)

    raster = %{__type__: :raster, width: 1, height: 1, format: :rgba8, data: <<255, 0, 0, 255>>}
    assert :ok = GPUI.Runtime.put_resource(pid, "logo", raster)

    {_event, [payload]} =
      GPUI.Runtime.dispatch_event(pid, %{type: :noop, window_id: 1, event: "noop"})

    assert get_in(payload, [:root, :tree, :attrs, :raster]) == raster

    GenServer.stop(pid)
  end

  test "native change events update view assigns" do
    {:ok, pid} = GPUI.Runtime.start_link(app: InputApp, backend: :native)
    [window] = GPUI.Runtime.windows(pid)

    assert {:ok, :ok} =
             GPUI.Runtime.emit_test_event(pid, %{
               type: :change,
               window_id: window.id,
               event: "rename",
               value: "new"
             })

    handled = GPUI.Runtime.drain_events(pid)
    assert %{type: :change, event: "rename", value: "new", window_id: 1} in handled

    [updated] = GPUI.Runtime.windows(pid)
    assert {_module, %{name: "new"}} = updated.root

    GenServer.stop(pid)
  end

  test "remote TCP backend reconnects and replays windows" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, pid} =
      GPUI.Runtime.start_link(
        app: CounterApp,
        backend: :remote_tcp,
        host: "127.0.0.1",
        port: port,
        session_id: "reconnect-test-session"
      )

    [window] = GPUI.Runtime.windows(pid)
    GenServer.stop(server)
    {:ok, _server} = GPUI.Remote.DisplayServer.start_link(port: port, display_backend: :data)

    assert {:ok, %{}} = GPUI.Runtime.emit_test_event(pid, %{window_id: window.id, event: "inc"})

    handled = GPUI.Runtime.drain_events(pid)
    assert %{type: :click, window_id: 1, event: "inc"} in handled

    [updated] = GPUI.Runtime.windows(pid)
    assert {_module, %{count: 1}} = updated.root

    GenServer.stop(pid)
  end

  test "remote TCP backend uses display server for event/update flow" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, pid} =
      GPUI.Runtime.start_link(
        app: CounterApp,
        backend: :remote_tcp,
        host: "127.0.0.1",
        port: port
      )

    [window] = GPUI.Runtime.windows(pid)

    assert {:ok, %{}} = GPUI.Runtime.emit_test_event(pid, %{window_id: window.id, event: "inc"})

    handled = GPUI.Runtime.drain_events(pid)
    assert %{type: :click, window_id: 1, event: "inc"} in handled

    [updated] = GPUI.Runtime.windows(pid)
    assert {_module, %{count: 1}} = updated.root

    assert %{op: :backend_event, payload: %{type: :window_updated, window_id: 1}} in GPUI.Runtime.host_messages(
             pid
           )

    GenServer.stop(pid)
  end

  test "remote loopback backend uses runtime protocol for event/update flow" do
    {:ok, pid} =
      GPUI.Runtime.start_link(app: CounterApp, backend: :remote_loopback, poll_interval: 10)

    [window] = GPUI.Runtime.windows(pid)

    assert {:ok, :ok} = GPUI.Runtime.emit_test_event(pid, %{window_id: window.id, event: "inc"})

    handled = GPUI.Runtime.drain_events(pid)
    assert %{type: :click, window_id: 1, event: "inc"} in handled

    [updated] = GPUI.Runtime.windows(pid)
    assert {_module, %{count: 1}} = updated.root

    assert %{op: :backend_event, payload: %{type: :window_updated, window_id: 1}} in GPUI.Runtime.host_messages(
             pid
           )

    GenServer.stop(pid)
  end

  test "native events can be polled automatically" do
    {:ok, pid} = GPUI.Runtime.start_link(app: CounterApp, backend: :native, poll_interval: 10)
    [window] = GPUI.Runtime.windows(pid)

    {:ok, :ok} =
      GPUI.Runtime.emit_test_event(pid, %{
        window_id: window.id,
        event: "inc"
      })

    assert_eventually(fn ->
      [updated] = GPUI.Runtime.windows(pid)
      assert {_module, %{count: 1}} = updated.root
    end)

    assert_eventually(fn ->
      assert %{op: :backend_event, payload: %{type: :click, event: "inc", window_id: 1}} in GPUI.Runtime.host_messages(
               pid
             )
    end)

    GenServer.stop(pid)
  end

  defp assert_eventually(fun) do
    deadline = System.monotonic_time(:millisecond) + 1_000
    assert_eventually(fun, deadline, nil)
  end

  defp assert_eventually(fun, deadline, last_error) do
    try do
      fun.()
    rescue
      error in [ExUnit.AssertionError] ->
        if System.monotonic_time(:millisecond) > deadline do
          reraise(error, __STACKTRACE__)
        else
          Process.sleep(10)
          assert_eventually(fun, deadline, error)
        end
    else
      result -> result
    catch
      kind, reason ->
        if System.monotonic_time(:millisecond) > deadline do
          :erlang.raise(kind, reason, __STACKTRACE__)
        else
          Process.sleep(10)
          assert_eventually(fun, deadline, last_error)
        end
    end
  end
end
