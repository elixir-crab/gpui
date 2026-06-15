defmodule GPUI.Remote.AppServerTest do
  use ExUnit.Case, async: false

  import GPUI.Template, only: [sigil_GPUI: 2]

  alias GPUI.Remote.AppProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  defmodule FormView do
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
    def handle_event("rename", %{value: value}, assigns), do: {:noreply, %{assigns | name: value}}
  end

  defmodule FormApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok, %{}, [window("Remote Form", do: root(FormView, name: "old"))]}
    end
  end

  test "serves remote app snapshots and events over SafeRPC" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, %{capabilities: capabilities}} =
             SafeRPC.call(client, :hello, AppProtocol.hello().payload)

    assert :app_server in capabilities

    assert {:ok, %{session_id: :default, windows: [%{id: 1, root: %{tree: mounted_tree}}]}} =
             SafeRPC.call(client, :mount, %{})

    assert mounted_tree.type == :div

    assert {:ok, %{windows: [%{root: %{assigns: %{name: "new"}}}]}} =
             SafeRPC.call(client, :event, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "new"
             })
  end

  test "display client mounts and forwards events to remote app server" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)

    {:ok, display} =
      GPUI.Remote.DisplayClient.start_link(host: "127.0.0.1", port: port, backend: :data)

    assert {:ok, [%{id: 1}]} = GPUI.Remote.DisplayClient.mount(display)

    assert {:ok, [%{root: %{assigns: %{name: "client"}}}]} =
             GPUI.Remote.DisplayClient.event(display, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "client"
             })
  end

  test "rejects operations before hello" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)
    {:ok, client} = raw_client(port)

    assert {:error, :handshake_required} = SafeRPC.call(client, :mount, %{})
  end

  test "tracks hello per connection" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)
    {:ok, client_a} = raw_client(port)
    {:ok, client_b} = raw_client(port)

    assert {:ok, _hello} = SafeRPC.call(client_a, :hello, AppProtocol.hello().payload)
    assert {:ok, %{windows: [%{id: 1}]}} = SafeRPC.call(client_a, :mount, %{})
    assert {:error, :handshake_required} = SafeRPC.call(client_b, :mount, %{})
  end

  test "garbage collects expired app sessions" do
    {:ok, server} =
      GPUI.Remote.AppServer.start_link(
        app: FormApp,
        port: 0,
        app_session_ttl: 20,
        app_session_gc_interval: 10
      )

    {:ok, port} = GPUI.Remote.AppServer.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, %{session_id: "gc-app", windows: [%{id: 1}]}} =
             SafeRPC.call(client, :mount, %{session_id: "gc-app"})

    assert_eventually(fn ->
      state = :sys.get_state(server)
      refute Map.has_key?(state.sessions, "gc-app")
    end)
  end

  test "resumes mounted app sessions" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, %{session_id: "stable", windows: [%{id: 1}]}} =
             SafeRPC.call(client, :mount, %{session_id: "stable"})

    assert {:ok, %{resumed: true, session_id: "stable", windows: [%{id: 1}]}} =
             SafeRPC.call(client, :resume_session, %{session_id: "stable"})
  end

  test "display client reconnects and remounts after app server restart" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)

    {:ok, display} =
      GPUI.Remote.DisplayClient.start_link(host: "127.0.0.1", port: port, backend: :data)

    assert {:ok, [%{id: 1}]} = GPUI.Remote.DisplayClient.mount(display)

    GenServer.stop(server)
    {:ok, _server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: port)

    assert {:ok, [%{root: %{assigns: %{name: "after-reconnect"}}}]} =
             GPUI.Remote.DisplayClient.event(display, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "after-reconnect"
             })
  end

  test "rejects unauthorized app clients" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)

    {:ok, client} =
      SafeRPC.Client.start_link(
        transport: SafeRPCTCP,
        host: "127.0.0.1",
        port: port,
        cap: :wrong_cap
      )

    assert {:error, :unauthorized} = SafeRPC.call(client, :hello, %{})
  end

  defp assert_eventually(fun) do
    deadline = System.monotonic_time(:millisecond) + 1_000
    assert_eventually(fun, deadline)
  end

  defp assert_eventually(fun, deadline) do
    try do
      fun.()
    rescue
      error in [ExUnit.AssertionError] ->
        if System.monotonic_time(:millisecond) > deadline do
          reraise(error, __STACKTRACE__)
        else
          Process.sleep(10)
          assert_eventually(fun, deadline)
        end
    end
  end

  defp start_client(port) do
    with {:ok, client} <- raw_client(port),
         {:ok, _hello} <- SafeRPC.call(client, :hello, AppProtocol.hello().payload) do
      {:ok, client}
    end
  end

  defp raw_client(port) do
    SafeRPC.Client.start_link(
      transport: SafeRPCTCP,
      host: "127.0.0.1",
      port: port,
      cap: AppProtocol.capability()
    )
  end
end
