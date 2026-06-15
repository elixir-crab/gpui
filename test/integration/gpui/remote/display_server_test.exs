defmodule GPUI.Remote.DisplayServerTest do
  use ExUnit.Case, async: false

  alias GPUI.Remote.DisplayProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  test "starts under an OTP supervisor" do
    {:ok, supervisor} =
      Supervisor.start_link(
        [
          {GPUI.Remote.DisplayServer,
           port: 0, display_backend: :data, name: __MODULE__.SupervisedDisplay}
        ],
        strategy: :one_for_one
      )

    assert {:ok, port} = GPUI.Remote.DisplayServer.port(__MODULE__.SupervisedDisplay)
    assert is_integer(port)

    Supervisor.stop(supervisor)
  end

  test "accepts multiple RemoteTCP clients" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, conn1} = start_client(port)
    {:ok, conn2} = start_client(port)

    assert %{connection_supervisor: connection_supervisor} = :sys.get_state(server)
    assert is_pid(connection_supervisor)

    hello = DisplayProtocol.hello(%{role: :test}).payload
    assert {:ok, %{capabilities: capabilities1}} = SafeRPC.call(conn1, :hello, hello)
    assert {:ok, %{capabilities: capabilities2}} = SafeRPC.call(conn2, :hello, hello)

    assert :display_server in capabilities1
    assert :safe_rpc in capabilities1
    assert :display_server in capabilities2
    assert :safe_rpc in capabilities2
  end

  test "keeps serving clients after one client disconnects" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, conn1} = start_client(port)
    {:ok, conn2} = start_client(port)

    GenServer.stop(conn1)
    Process.sleep(10)

    assert {:ok, %{capabilities: capabilities}} =
             SafeRPC.call(conn2, :hello, DisplayProtocol.hello(%{role: :test}).payload)

    assert :display_server in capabilities
  end

  test "garbage collects expired sessions" do
    {:ok, server} =
      GPUI.Remote.DisplayServer.start_link(
        port: 0,
        display_backend: :data,
        session_ttl: 20,
        session_gc_interval: 10
      )

    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, %{}} =
             SafeRPC.call(client, :open_window, %{id: 1, title: "GC"},
               meta: %{session_id: "gc-session"}
             )

    assert_eventually(fn ->
      state = :sys.get_state(server)
      refute Map.has_key?(state.sessions, "gc-session")
    end)
  end

  test "retains active sessions while they are touched" do
    {:ok, server} =
      GPUI.Remote.DisplayServer.start_link(
        port: 0,
        display_backend: :data,
        session_ttl: 50,
        session_gc_interval: 10
      )

    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)

    for _ <- 1..3 do
      assert {:ok, %{pong: true}} =
               SafeRPC.call(client, :ping, %{}, meta: %{session_id: "active-session"})

      Process.sleep(20)
    end

    state = :sys.get_state(server)
    assert Map.has_key?(state.sessions, "active-session")
  end

  test "RemoteTCP backend stores resources on the display server" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, backend} =
      GPUI.Backend.RemoteTCP.init(host: "127.0.0.1", port: port, session_id: "backend-resource")

    assert :ok = GPUI.Backend.RemoteTCP.put_resource(backend, "logo", %{type: :raster})

    state = :sys.get_state(server)
    assert get_in(state.sessions, ["backend-resource", :resources, "logo"]) == %{type: :raster}

    assert :ok = GPUI.Backend.RemoteTCP.drop_resource(backend, "logo")

    state = :sys.get_state(server)
    refute Map.has_key?(get_in(state.sessions, ["backend-resource", :resources]), "logo")
  end

  test "stores and drops resources per session" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)
    session_id = "resource-session"

    resource = %{type: :raster, width: 1, height: 1}

    assert {:ok, %{}} =
             SafeRPC.call(client, :put_resource, %{id: "logo", resource: resource},
               meta: %{session_id: session_id}
             )

    state = :sys.get_state(server)
    assert get_in(state.sessions, [session_id, :resources, "logo"]) == resource

    assert {:ok, %{}} =
             SafeRPC.call(client, :drop_resource, %{id: "logo"}, meta: %{session_id: session_id})

    state = :sys.get_state(server)
    refute Map.has_key?(get_in(state.sessions, [session_id, :resources]), "logo")
  end

  test "responds to ping for heartbeat checks" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, %{pong: true}} = SafeRPC.call(client, :ping, %{})
  end

  test "rejects updates for windows not opened by the session" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)

    assert {:error, :unknown_window} =
             SafeRPC.call(
               client,
               :update_window,
               %{window_id: 1, tree: %{type: :div}},
               meta: %{session_id: "session-a"}
             )
  end

  test "allows updates only for windows opened by the same session" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client_a} = start_client(port)
    {:ok, client_b} = start_client(port)

    window = %{id: 1, title: "Owned", root: %{tree: %{type: :div}}}

    assert {:ok, %{}} =
             SafeRPC.call(client_a, :open_window, window, meta: %{session_id: "session-a"})

    assert {:error, :unknown_window} =
             SafeRPC.call(
               client_b,
               :update_window,
               %{window_id: 1, tree: %{type: :text}},
               meta: %{session_id: "session-b"}
             )

    assert {:ok, %{}} =
             SafeRPC.call(
               client_a,
               :update_window,
               %{window_id: 1, tree: %{type: :text}},
               meta: %{session_id: "session-a"}
             )
  end

  test "resume_session returns known windows for a session" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)
    session_id = "resume-session"

    window = %{id: 1, title: "Resume"}

    assert {:ok, %{}} =
             SafeRPC.call(client, :open_window, window, meta: %{session_id: session_id})

    assert {:ok, %{session_id: ^session_id, windows: [^window]}} =
             SafeRPC.call(client, :resume_session, %{session_id: session_id},
               meta: %{session_id: session_id}
             )
  end

  test "preserves session windows across reconnect when session id is reused" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    session_id = "stable-session"

    {:ok, first_client} = start_client(port)

    assert {:ok, %{}} =
             SafeRPC.call(first_client, :open_window, %{id: 1, title: "Reconnect"},
               meta: %{session_id: session_id}
             )

    GenServer.stop(first_client)

    {:ok, second_client} = start_client(port)

    assert {:ok, %{}} =
             SafeRPC.call(
               second_client,
               :update_window,
               %{window_id: 1, tree: %{type: :div}},
               meta: %{session_id: session_id}
             )
  end

  test "isolates event queues per session" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client_a} = start_client(port)
    {:ok, client_b} = start_client(port)

    session_a = "session-a"
    session_b = "session-b"

    assert {:ok, %{}} =
             SafeRPC.call(
               client_a,
               :event,
               %{type: :click, window_id: 1, event: "a"},
               meta: %{session_id: session_a}
             )

    assert {:ok, %{}} =
             SafeRPC.call(
               client_b,
               :event,
               %{type: :click, window_id: 1, event: "b"},
               meta: %{session_id: session_b}
             )

    assert {:ok, %{events: [%{event: "a"}]}} =
             SafeRPC.call(client_a, :drain_events, %{}, meta: %{session_id: session_a})

    assert {:ok, %{events: [%{event: "b"}]}} =
             SafeRPC.call(client_b, :drain_events, %{}, meta: %{session_id: session_b})

    assert {:ok, %{events: []}} =
             SafeRPC.call(client_a, :drain_events, %{}, meta: %{session_id: session_a})
  end

  test "isolates window update events per session" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client_a} = start_client(port)
    {:ok, client_b} = start_client(port)

    session_a = "session-a"
    session_b = "session-b"

    assert {:ok, %{}} =
             SafeRPC.call(client_a, :open_window, %{id: 1, title: "A"},
               meta: %{session_id: session_a}
             )

    assert {:ok, %{}} =
             SafeRPC.call(
               client_a,
               :update_window,
               %{window_id: 1, tree: %{type: :div}},
               meta: %{session_id: session_a}
             )

    assert {:ok, %{events: [%{type: :window_updated, window_id: 1}]}} =
             SafeRPC.call(client_a, :drain_events, %{}, meta: %{session_id: session_a})

    assert {:ok, %{events: []}} =
             SafeRPC.call(client_b, :drain_events, %{}, meta: %{session_id: session_b})
  end

  test "rejects operations before hello" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = raw_client(port)

    assert {:error, :handshake_required} = SafeRPC.call(client, :ping, %{})
  end

  test "tracks hello per connection" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client_a} = raw_client(port)
    {:ok, client_b} = raw_client(port)

    assert {:ok, _hello} = SafeRPC.call(client_a, :hello, DisplayProtocol.hello().payload)
    assert {:ok, %{pong: true}} = SafeRPC.call(client_a, :ping, %{})
    assert {:error, :handshake_required} = SafeRPC.call(client_b, :ping, %{})
  end

  test "rejects unsupported operations after hello" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)

    assert {:error, {:unsupported_op, :unknown}} = SafeRPC.call(client, :unknown, %{})
  end

  test "enforces resource, window, and event quotas" do
    {:ok, server} =
      GPUI.Remote.DisplayServer.start_link(
        port: 0,
        display_backend: :data,
        max_resources_per_session: 1,
        max_resource_bytes_per_session: 4,
        max_windows_per_session: 1,
        max_queued_events_per_session: 1
      )

    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)
    meta = %{session_id: "quota"}

    assert {:ok, %{}} = SafeRPC.call(client, :open_window, %{id: 1, title: "one"}, meta: meta)

    assert {:error, :max_windows_per_session} =
             SafeRPC.call(client, :open_window, %{id: 2, title: "two"}, meta: meta)

    assert {:ok, %{}} =
             SafeRPC.call(client, :put_resource, %{id: "a", resource: %{data: <<1, 2, 3, 4>>}},
               meta: meta
             )

    assert {:error, :max_resource_bytes_per_session} =
             SafeRPC.call(client, :put_resource, %{id: "a", resource: %{data: <<1, 2, 3, 4, 5>>}},
               meta: meta
             )

    assert {:error, :max_resources_per_session} =
             SafeRPC.call(client, :put_resource, %{id: "b", resource: %{data: <<1>>}}, meta: meta)

    assert {:ok, %{}} = SafeRPC.call(client, :event, %{type: :click}, meta: meta)

    assert {:error, :max_queued_events_per_session} =
             SafeRPC.call(client, :event, %{type: :click}, meta: meta)
  end

  test "rejects unauthorized capabilities" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, client} =
      SafeRPC.Client.start_link(
        transport: SafeRPCTCP,
        host: "127.0.0.1",
        port: port,
        cap: :wrong_cap
      )

    assert {:error, :unauthorized} = SafeRPC.call(client, :hello, %{role: :test})
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
         {:ok, _hello} <-
           SafeRPC.call(client, :hello, DisplayProtocol.hello(%{role: :test}).payload) do
      {:ok, client}
    end
  end

  defp raw_client(port) do
    SafeRPC.Client.start_link(
      transport: SafeRPCTCP,
      host: "127.0.0.1",
      port: port,
      cap: DisplayProtocol.capability()
    )
  end
end
