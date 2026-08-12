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

    def handle_event("file_selected", %{value: value}, assigns),
      do: {:noreply, %{assigns | file: value}}

    def handle_event("records_range", %{value: value}, assigns),
      do: {:noreply, %{assigns | range: value}}

    def handle_event("tree_toggled", %{value: value}, assigns),
      do: {:noreply, %{assigns | tree_branch: value}}

    def handle_event("open_details", _event, assigns) do
      details = %GPUI.WindowSpec{
        key: "details",
        title: "Remote Details",
        root: {FormView, Map.put(assigns, :name, "details")}
      }

      {:open_window, details, %{assigns | name: "main-opened"}}
    end

    def handle_event("close_details", _event, assigns),
      do: {:close_window, "details", %{assigns | name: "main-closed"}}

    def handle_event("increment", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}

    def handle_event("crash", _event, _assigns), do: raise("view failed")
  end

  defmodule FormApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(args) do
      name = Map.get(Map.new(args), :name, "old")

      {:ok,
       [
         window("Remote Form",
           do: root(FormView, name: name, file: nil, range: nil, tree_branch: nil, count: 0)
         )
       ]}
    end
  end

  test "serves renderer-independent snapshots and events" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, %{session_id: "form", snapshot: %{windows: [%{root: %{tree: tree}}]}}} =
             SafeRPC.call(client, :mount, %{session_id: "form", args: %{name: "old"}})

    assert %{type: :viewport, attrs: %{}, children: [%{type: :div}]} = tree

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{name: "new"}}}]}}} =
             SafeRPC.call(client, :event, %{
               session_id: "form",
               type: :change,
               window_id: 1,
               event: "rename",
               value: "new"
             })
  end

  test "remote event outcomes synchronize and resume keyed multi-window topology" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "topology"})

    assert {:ok,
            %{snapshot: %{windows: [%{id: 1, root: %{assigns: %{name: "main-opened"}}}, details]}}} =
             SafeRPC.call(client, :event, %{
               session_id: "topology",
               type: :click,
               window_id: 1,
               event: "open_details"
             })

    assert details.id == 2
    assert details.key == "details"
    assert details.root.assigns.name == "details"

    GenServer.stop(client)
    {:ok, resumed_client} = start_client(port)

    assert {:ok, %{resumed: true, snapshot: %{windows: [main, resumed_details]}}} =
             SafeRPC.call(resumed_client, :resume_session, %{session_id: "topology"})

    assert main.id == 1
    assert main.root.assigns.name == "main-opened"
    assert resumed_details.id == 2
    assert resumed_details.key == "details"

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{name: "main-closed"}}}]}}} =
             SafeRPC.call(resumed_client, :event, %{
               session_id: "topology",
               type: :click,
               window_id: 1,
               event: "close_details"
             })

    assert {:ok, %{snapshot: %{windows: [_, reopened]}}} =
             SafeRPC.call(resumed_client, :event, %{
               session_id: "topology",
               type: :click,
               window_id: 1,
               event: "open_details"
             })

    assert reopened.id == 3
    assert reopened.key == "details"
  end

  test "deduplicates retried mounts without replacing the live session" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    mount = %{session_id: "stable-mount", request_id: "mount-17", args: %{name: "first"}}
    assert {:ok, _reply} = SafeRPC.call(client, :mount, mount)
    session = server_state(server).session_registry.sessions["stable-mount"].pid

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{name: "changed"}}}]}}} =
             SafeRPC.call(client, :event, %{
               session_id: "stable-mount",
               type: :change,
               window_id: 1,
               event: "rename",
               value: "changed"
             })

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{name: "changed"}}}]}}} =
             SafeRPC.call(client, :mount, mount)

    assert server_state(server).session_registry.sessions["stable-mount"].pid == session
  end

  test "deduplicates retried events within a session" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "deduplicated"})

    event = %{
      session_id: "deduplicated",
      request_id: 17,
      type: :click,
      window_id: 1,
      event: "increment"
    }

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{count: 1}}}]}}} =
             SafeRPC.call(client, :event, event)

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{count: 1}}}]}}} =
             SafeRPC.call(client, :event, event)
  end

  test "contains a crashing session without terminating the remote server" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)
    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "crashing"})

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:error, {:session_unavailable, _reason}} =
               SafeRPC.call(client, :event, %{
                 session_id: "crashing",
                 type: :click,
                 window_id: 1,
                 event: "crash"
               })
    end)

    assert Process.alive?(server)
    assert {:error, :unknown_session} = SafeRPC.call(client, :snapshot, %{session_id: "crashing"})
    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "healthy"})
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

  defmodule BlockingView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div>{assigns.id}</div>
      """
    end

    @impl GPUI.View
    def handle_event("block", _event, assigns) do
      send(assigns.owner, {:remote_session_blocked, self()})

      receive do
        :release_remote_session -> {:noreply, assigns}
      end
    end
  end

  defmodule BlockingApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(args) do
      args = Map.new(args)
      maybe_block_mount(args)

      {:ok,
       [
         window("Blocking Session",
           do: root(BlockingView, owner: Map.fetch!(args, :owner), id: Map.fetch!(args, :id))
         )
       ]}
    end

    defp maybe_block_mount(%{id: "blocked-mount", owner: owner}) do
      send(owner, {:remote_mount_blocked, self()})

      receive do
        :release_remote_mount -> :ok
      end
    end

    defp maybe_block_mount(_args), do: :ok
  end

  test "blocked session work does not delay unrelated remote sessions" do
    owner = Module.concat(__MODULE__, ConcurrencyOwner)
    Process.register(self(), owner)
    on_exit(fn -> if Process.whereis(owner), do: Process.unregister(owner) end)

    {:ok, server} =
      GPUI.Remote.Server.start_link(
        app: BlockingApp,
        args: %{owner: owner, id: "default"},
        port: 0,
        max_in_flight_requests_per_connection: 8,
        max_in_flight_requests_per_session: 1
      )

    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, _reply} =
             SafeRPC.call(client, :mount, %{
               session_id: "blocked-a",
               args: %{owner: owner, id: "a"}
             })

    assert {:ok, _reply} =
             SafeRPC.call(client, :mount, %{
               session_id: "responsive-b",
               args: %{owner: owner, id: "b"}
             })

    blocked_call =
      Task.async(fn ->
        SafeRPC.call(client, :event, %{
          session_id: "blocked-a",
          type: :click,
          window_id: 1,
          event: "block"
        })
      end)

    assert_receive {:remote_session_blocked, blocked_session}

    assert {:error, :overloaded} =
             SafeRPC.call(client, :snapshot, %{session_id: "blocked-a"})

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{id: "b"}}}]}}} =
             SafeRPC.call(client, :snapshot, %{session_id: "responsive-b"})

    assert {:ok, ^port} = GPUI.Remote.Server.port(server)
    send(blocked_session, :release_remote_session)

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{id: "a"}}}]}}} =
             Task.await(blocked_call)

    blocked_mount =
      Task.async(fn ->
        SafeRPC.call(client, :mount, %{
          session_id: "blocked-mount",
          args: %{owner: owner, id: "blocked-mount"}
        })
      end)

    assert_receive {:remote_mount_blocked, mounting_session}

    assert {:error, :overloaded} =
             SafeRPC.call(client, :snapshot, %{session_id: "blocked-mount"})

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{id: "b"}}}]}}} =
             SafeRPC.call(client, :snapshot, %{session_id: "responsive-b"})

    assert {:ok, ^port} = GPUI.Remote.Server.port(server)
    send(mounting_session, :release_remote_mount)

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{id: "blocked-mount"}}}]}}} =
             Task.await(blocked_mount)
  end

  test "server shutdown interrupts a blocked application mount" do
    owner = Module.concat(__MODULE__, ShutdownOwner)
    Process.register(self(), owner)
    on_exit(fn -> if Process.whereis(owner), do: Process.unregister(owner) end)

    {:ok, server} =
      GPUI.Remote.Server.start_link(
        app: BlockingApp,
        args: %{owner: owner, id: "default"},
        port: 0
      )

    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    blocked_mount =
      Task.async(fn ->
        SafeRPC.call(client, :mount, %{
          session_id: "shutdown-mount",
          args: %{owner: owner, id: "blocked-mount"}
        })
      end)

    assert_receive {:remote_mount_blocked, mounting_session}
    mount_monitor = Process.monitor(mounting_session)

    assert :ok = Supervisor.stop(server)
    assert_receive {:DOWN, ^mount_monitor, :process, ^mounting_session, _reason}
    Task.shutdown(blocked_mount, :brutal_kill)
  end

  test "connection request limits reject excess delegated work" do
    owner = Module.concat(__MODULE__, ConnectionLimitOwner)
    Process.register(self(), owner)
    on_exit(fn -> if Process.whereis(owner), do: Process.unregister(owner) end)

    {:ok, server} =
      GPUI.Remote.Server.start_link(
        app: BlockingApp,
        args: %{owner: owner, id: "default"},
        port: 0,
        max_in_flight_requests_per_connection: 1,
        max_in_flight_requests_per_session: 4
      )

    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    for {session_id, id} <- [{"limited-a", "a"}, {"limited-b", "b"}] do
      assert {:ok, _reply} =
               SafeRPC.call(client, :mount, %{
                 session_id: session_id,
                 args: %{owner: owner, id: id}
               })
    end

    blocked_call =
      Task.async(fn ->
        SafeRPC.call(client, :event, %{
          session_id: "limited-a",
          type: :click,
          window_id: 1,
          event: "block"
        })
      end)

    assert_receive {:remote_session_blocked, blocked_session}
    assert {:error, :overloaded} = SafeRPC.call(client, :snapshot, %{session_id: "limited-b"})

    assert {:error, :overloaded} =
             SafeRPC.call(client, :mount, %{
               session_id: "rejected-mount",
               args: %{owner: owner, id: "rejected"}
             })

    refute Map.has_key?(server_state(server).session_registry.sessions, "rejected-mount")
    send(blocked_session, :release_remote_session)
    assert {:ok, _snapshot} = Task.await(blocked_call)

    assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{id: "b"}}}]}}} =
             SafeRPC.call(client, :snapshot, %{session_id: "limited-b"})
  end

  test "serves many isolated sessions concurrently within configured limits" do
    {:ok, server} =
      GPUI.Remote.Server.start_link(
        app: FormApp,
        port: 0,
        max_in_flight_requests_per_connection: 128,
        max_in_flight_requests_per_session: 4
      )

    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    session_ids = Enum.map(1..50, &"load-#{&1}")

    for session_id <- session_ids do
      assert {:ok, _reply} =
               SafeRPC.call(client, :mount, %{
                 session_id: session_id,
                 args: %{name: session_id}
               })
    end

    requests =
      Enum.map(session_ids, fn session_id ->
        {session_id, SafeRPC.async(client, :snapshot, %{session_id: session_id})}
      end)

    for {session_id, request} <- requests do
      assert {:ok, %{snapshot: %{windows: [%{root: %{assigns: %{name: ^session_id}}}]}}} =
               SafeRPC.await(request)
    end

    [%{owner: owner}] = server |> server_state() |> Map.fetch!(:connections) |> Map.values()
    assert %{delegates: %{}} = :sys.get_state(owner)
    assert Process.alive?(server)
  end

  test "remote clients reject invalid polling intervals before connecting" do
    assert {:error, {:invalid_option, :poll_interval}} =
             GPUI.Remote.Client.start_link(
               host: "127.0.0.1",
               port: 1,
               display: GPUI.Test.Display,
               poll_interval: 0
             )
  end

  test "rejects invalid remote request limits during startup" do
    previous = Process.flag(:trap_exit, true)

    assert {:error, {:invalid_option, :max_in_flight_requests_per_connection}} =
             GPUI.Remote.Server.start_link(
               app: FormApp,
               port: 0,
               max_in_flight_requests_per_connection: 0
             )

    assert {:error, {:invalid_option, :max_in_flight_requests_per_session}} =
             GPUI.Remote.Server.start_link(
               app: FormApp,
               port: 0,
               max_in_flight_requests_per_session: 4_097
             )

    assert {:error, {:invalid_option, :session_ttl}} =
             GPUI.Remote.Server.start_link(
               app: FormApp,
               port: 0,
               session_ttl: -1
             )

    Process.flag(:trap_exit, previous)
  end

  defmodule RecoveringDisplay do
    @behaviour GPUI.Display

    use Agent

    @impl GPUI.Display
    def start_link(_opts), do: Agent.start_link(fn -> :fail_next_sync end)

    @impl GPUI.Display
    def sync(display, _snapshot) do
      Agent.get_and_update(display, fn
        :fail_next_sync -> {{:error, :injected_sync_failure}, :ready}
        :ready -> {:ok, :ready}
      end)
    end

    @impl GPUI.Display
    def drain_events(_display), do: {:ok, []}

    @impl GPUI.Display
    def inject_event(_display, _event), do: {:ok, :ok}
  end

  test "remote client reports display synchronization failures and can retry" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: RecoveringDisplay,
        poll_interval: nil
      )

    assert {:error, {:display_sync_failed, :injected_sync_failure}} =
             GPUI.Remote.Client.mount(client, %{name: "retained"})

    assert Process.alive?(client)

    assert {:ok, %{windows: [%{root: %{assigns: %{name: "retained"}}}]}} =
             GPUI.Remote.Client.snapshot(client)
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

    assert {:ok, :ok} =
             GPUI.Test.Display.inject_event(display_name, %{
               type: :submit,
               window_id: 1,
               event: "rename",
               value: "submitted"
             })

    assert_receive {:gpui, ^client,
                    %GPUI.Runtime.Update{
                      events: [%{type: :submit, value: "submitted"}],
                      snapshot: %{windows: [%{root: %{assigns: %{name: "submitted"}}}]}
                    }}

    assert {:ok, :ok} =
             GPUI.Test.Display.inject_event(display_name, %{
               type: :command,
               window_id: 1,
               event: "increment"
             })

    assert_receive {:gpui, ^client,
                    %GPUI.Runtime.Update{
                      events: [%{type: :command}],
                      snapshot: %{windows: [%{root: %{assigns: %{name: "submitted", count: 1}}}]}
                    }}

    selection = %{
      operation_id: 17,
      status: :selected,
      name: "remote.png",
      size: 4,
      data: <<1, 2, 3, 4>>
    }

    assert {:ok, :ok} =
             GPUI.Test.Display.inject_event(display_name, %{
               type: :change,
               window_id: 1,
               event: "file_selected",
               value: selection
             })

    assert_receive {:gpui, ^client,
                    %GPUI.Runtime.Update{
                      snapshot: %{windows: [%{root: %{assigns: %{file: ^selection}}}]}
                    }}

    range = %{first: 40_000, last: 40_048}

    assert {:ok, :ok} =
             GPUI.Test.Display.inject_event(display_name, %{
               type: :range,
               window_id: 1,
               event: "records_range",
               value: range
             })

    assert_receive {:gpui, ^client,
                    %GPUI.Runtime.Update{
                      events: [%{type: :range, value: ^range}],
                      snapshot: %{windows: [%{root: %{assigns: %{range: ^range}}}]}
                    }}

    assert {:ok, :ok} =
             GPUI.Test.Display.inject_event(display_name, %{
               type: :change,
               window_id: 1,
               event: "tree_toggled",
               value: "dir:lib"
             })

    assert_receive {:gpui, ^client,
                    %GPUI.Runtime.Update{
                      events: [%{type: :change, value: "dir:lib"}],
                      snapshot: %{windows: [%{root: %{assigns: %{tree_branch: "dir:lib"}}}]}
                    }}
  end

  test "remote client retains local display events across server outages" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    display_name = Module.concat(__MODULE__, RetryingDisplay)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: GPUI.Test.Display,
        display_opts: [name: display_name],
        poll_interval: nil
      )

    assert {:ok, _snapshot} = GPUI.Remote.Client.mount(client, %{name: "before-outage"})
    :ok = GenServer.stop(server)

    assert {:ok, :ok} =
             GPUI.Test.Display.inject_event(display_name, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "after-outage"
             })

    send(client, :poll_display)
    assert %{pending_events: [_event]} = :sys.get_state(client)

    {:ok, _replacement_server} = GPUI.Remote.Server.start_link(app: FormApp, port: port)
    send(client, :poll_display)
    assert %{pending_events: []} = :sys.get_state(client)

    assert {:ok, %{windows: [%{root: %{assigns: %{name: "after-outage"}}}]}} =
             GPUI.Remote.Client.snapshot(client)
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

  test "stops connection owners when the server terminates" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, _client} = start_client(port)

    [%{owner: owner}] = server |> server_state() |> Map.fetch!(:connections) |> Map.values()
    monitor = Process.monitor(owner)

    :ok = Supervisor.stop(server)
    assert_receive {:DOWN, ^monitor, :process, ^owner, _reason}
  end

  test "connection supervision tears down siblings and accepts a replacement" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, _client} = start_client(port)

    [{tree, %{owner: owner}}] = server_state(server).connections |> Map.to_list()
    {:ok, rpc} = GPUI.Remote.Supervision.child(tree, :rpc, :connection_unavailable)
    tree_monitor = Process.monitor(tree)
    rpc_monitor = Process.monitor(rpc)

    Process.exit(owner, :kill)

    assert_receive {:DOWN, ^rpc_monitor, :process, ^rpc, _reason}
    assert_receive {:DOWN, ^tree_monitor, :process, ^tree, _reason}
    assert {:ok, _replacement} = start_client(port)
    assert Process.alive?(server)
  end

  test "removes terminated sessions without waiting for garbage collection" do
    {:ok, server} =
      GPUI.Remote.Server.start_link(
        app: FormApp,
        port: 0,
        session_ttl: :infinity
      )

    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)
    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "terminated"})

    session = server_state(server).session_registry.sessions["terminated"].pid
    monitor = Process.monitor(session)
    Supervisor.stop(session)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}

    assert {:error, :unknown_session} =
             SafeRPC.call(client, :resume_session, %{session_id: "terminated"})

    refute Map.has_key?(server_state(server).session_registry.sessions, "terminated")
  end

  test "expires inactive sessions" do
    {:ok, server} =
      GPUI.Remote.Server.start_link(
        app: FormApp,
        port: 0,
        session_ttl: 20
      )

    {:ok, port} = GPUI.Remote.Server.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, _reply} = SafeRPC.call(client, :mount, %{session_id: "expired"})
    session = server_state(server).session_registry.sessions["expired"].pid
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

  test "remote client reports negotiation failures during startup" do
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.Server.port(server)
    previous = Process.flag(:trap_exit, true)

    assert {:error, {:rpc_start_failed, :unauthorized}} =
             GPUI.Remote.Client.start_link(
               host: "127.0.0.1",
               port: port,
               cap: :wrong_cap,
               display: GPUI.Test.Display
             )

    Process.flag(:trap_exit, previous)
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

  defp server_state(server) do
    {:ok, coordinator} = GPUI.Remote.Server.coordinator(server)
    :sys.get_state(coordinator)
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
