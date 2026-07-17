defmodule GPUI.Remote.ServerTest do
  use ExUnit.Case, async: false

  alias GPUI.Remote.Protocol
  alias GPUI.Remote.Transport.TCP

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
    def mount(args) do
      name = Map.get(Map.new(args), :name, "old")
      {:ok, [window("Remote Form", do: root(FormView, name: name))]}
    end
  end

  test "serves renderer-independent snapshots and events" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, %{session_id: "form", snapshot: %{windows: [%{root: %{tree: tree}}]}}} =
             SafeRPC.call(client, :mount, %{session_id: "form", args: %{name: "old"}})

    assert tree.type == :div

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{name: "new"}}}]}}} =
             SafeRPC.call(client, :event, %{
               session_id: "form",
               type: :change,
               window_id: 1,
               event: "rename",
               value: "new"
             })
  end

  test "isolates application state by session" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "a", args: %{name: "A"}})
    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "b", args: %{name: "B"}})

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{name: "A"}}}]}}} =
             SafeRPC.call(client, :snapshot, %{session_id: "a"})

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{name: "B"}}}]}}} =
             SafeRPC.call(client, :snapshot, %{session_id: "b"})
  end

  test "remote client synchronizes snapshots into its local display" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: GPUI.Test.Display,
        display_opts: [owner: self()]
      )

    assert {:ok, %{windows: [%{id: 1}]}} = GPUI.Remote.Client.mount(client, %{name: "old"})
    assert_receive {:gpui_snapshot, %{windows: [%{id: 1}]}}
    assert {:ok, 0} = GPUI.Remote.Client.frame_token(client, 1)
    assert :ok = GPUI.Remote.Client.await_frame_after(client, 1, 0)
    assert :ok = GPUI.Remote.Client.subscribe(client)

    event = %{
      type: :change,
      window_id: 1,
      event: "rename",
      value: "client"
    }

    assert {:ok, %{windows: [%{root: %{assigns: %{name: "client"}}}]}} =
             GPUI.Remote.Client.event(client, event)

    assert_receive {:gpui, ^client,
                    %GPUI.Runtime.Update{
                      revision: 2,
                      events: [^event],
                      snapshot: %{windows: [%{root: %{assigns: %{name: "client"}}}]}
                    }}

    assert :ok = GPUI.Remote.Client.unsubscribe(client)
    assert {:ok, _snapshot} = GPUI.Remote.Client.event(client, %{event | value: "silent"})
    refute_receive {:gpui, ^client, %GPUI.Runtime.Update{}}
  end

  test "remote client remains responsive across repeated updates and connection replacement" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: GPUI.Test.Display,
        poll_interval: nil
      )

    assert {:ok, _snapshot} = GPUI.Remote.Client.mount(client, %{name: "initial"})

    final_snapshot =
      Enum.reduce(1..25, nil, fn iteration, _snapshot ->
        assert {:ok, snapshot} =
                 GPUI.Remote.Client.event(client, %{
                   type: :change,
                   window_id: 1,
                   event: "rename",
                   value: "update-#{iteration}"
                 })

        snapshot
      end)

    assert %{windows: [%{root: %{assigns: %{name: "update-25"}}}]} = final_snapshot

    rpc = :sys.get_state(client).rpc
    :ok = GenServer.stop(rpc)
    refute Process.alive?(rpc)

    assert {:ok, %{windows: [%{root: %{assigns: %{name: "update-25"}}}]}} =
             GPUI.Remote.Client.snapshot(client)

    assert Process.alive?(client)
    assert Process.alive?(:sys.get_state(client).display)
  end

  test "remote client forwards local display events automatically" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    display_name = Module.concat(__MODULE__, PollingDisplay)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: GPUI.Test.Display,
        display_opts: [name: display_name],
        poll_interval: 10
      )

    assert {:ok, _snapshot} = GPUI.Remote.Client.mount(client, %{name: "old"})
    assert :ok = GPUI.Remote.Client.subscribe(client)

    assert {:ok, :ok} =
             GPUI.Test.Display.inject_event(display_name, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "polled"
             })

    assert_receive {:gpui, ^client,
                    %GPUI.Runtime.Update{
                      snapshot: %{windows: [%{root: %{assigns: %{name: "polled"}}}]}
                    }}
  end

  test "remote client ignores display diagnostics that are not user input" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    display_name = Module.concat(__MODULE__, DiagnosticDisplay)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: GPUI.Test.Display,
        display_opts: [name: display_name],
        poll_interval: 10
      )

    assert {:ok, _snapshot} = GPUI.Remote.Client.mount(client, %{name: "unchanged"})
    assert {:ok, :ok} = GPUI.Test.Display.inject_event(display_name, "native diagnostic")

    assert {:ok, :ok} =
             GPUI.Test.Display.inject_event(display_name, %{
               type: :missing_resource,
               window_id: 1,
               id: "missing"
             })

    send(client, :poll_display)
    _state = :sys.get_state(client)
    assert Process.alive?(client)

    assert {:ok, %{windows: [%{root: %{assigns: %{name: "unchanged"}}}]}} =
             GPUI.Remote.Client.snapshot(client)
  end

  test "rejects malformed operation payloads without crashing the server" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    malformed = [
      hello: "invalid",
      mount: "invalid",
      resume_session: %{},
      event: %{},
      snapshot: %{}
    ]

    for {operation, payload} <- malformed do
      assert {:error, {:invalid_payload, ^operation}} = SafeRPC.call(client, operation, payload)
      assert Process.alive?(server)
    end

    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "recovered"})
  end

  test "requires hello independently for every connection" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client_a} = raw_client(port)
    {:ok, client_b} = raw_client(port)

    assert {:ok, _hello} = SafeRPC.call(client_a, :hello, Protocol.hello().payload)
    assert {:ok, _snapshot} = SafeRPC.call(client_a, :mount, %{session_id: "a"})
    assert {:error, :handshake_required} = SafeRPC.call(client_b, :mount, %{session_id: "b"})
  end

  test "expires inactive sessions" do
    {:ok, server} =
      GPUI.Remote.Server.start_link(
        app: FormApp,
        port: 0,
        session_ttl: 20,
        session_gc_interval: 10
      )

    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "expired"})
    session = :sys.get_state(server).sessions["expired"].pid
    monitor = Process.monitor(session)
    assert_receive {:DOWN, ^monitor, :process, ^session, _reason}, 1_000

    assert {:error, :unknown_session} =
             SafeRPC.call(client, :resume_session, %{session_id: "expired"})
  end

  test "resumes a live session" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "stable"})

    assert {:ok, %{resumed: true, session_id: "stable", snapshot: %{windows: [%{id: 1}]}}} =
             SafeRPC.call(client, :resume_session, %{session_id: "stable"})
  end

  test "rejects unauthorized clients" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)

    {:ok, client} =
      SafeRPC.Client.start_link(
        transport: TCP,
        host: "127.0.0.1",
        port: port,
        cap: :wrong_cap
      )

    assert {:error, :unauthorized} = SafeRPC.call(client, :hello, %{})
  end

  defp start_client(port) do
    with {:ok, client} <- raw_client(port),
         {:ok, _hello} <- SafeRPC.call(client, :hello, Protocol.hello().payload) do
      {:ok, client}
    end
  end

  defp raw_client(port) do
    SafeRPC.Client.start_link(
      transport: TCP,
      host: "127.0.0.1",
      port: port,
      cap: Protocol.capability()
    )
  end
end
