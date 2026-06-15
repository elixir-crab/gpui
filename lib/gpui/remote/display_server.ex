defmodule GPUI.Remote.DisplayServer do
  @moduledoc """
  Remote display endpoint for GPUI runtime protocol messages.

  The server accepts TCP/SSL connections and delegates per-client SafeRPC
  request decoding, worker management, replies, and safe ETF handling to
  `SafeRPC.Server.Connection`. GPUI owns only the display operations.
  """

  use GenServer

  alias GPUI.Remote.ConnectionOwner
  alias GPUI.Remote.DisplayProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Server.Connection

  @display_capability DisplayProtocol.capability()

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @spec port(GenServer.server()) :: {:ok, :inet.port_number()} | {:error, term()}
  def port(server), do: GenServer.call(server, :port)

  @impl GenServer
  def init(opts) do
    display_backend = opts |> Keyword.get(:display_backend, :data) |> GPUI.Backend.module_for()
    display_backend_opts = Keyword.get(opts, :display_backend_opts, [])

    listen_opts = [port: Keyword.get(opts, :port, 0), ssl: Keyword.get(opts, :ssl, false)]
    session_ttl = Keyword.get(opts, :session_ttl, :timer.minutes(30))
    session_gc_interval = Keyword.get(opts, :session_gc_interval, :timer.minutes(1))

    limits = %{
      max_resources_per_session: Keyword.get(opts, :max_resources_per_session, :infinity),
      max_resource_bytes_per_session:
        Keyword.get(opts, :max_resource_bytes_per_session, :infinity),
      max_windows_per_session: Keyword.get(opts, :max_windows_per_session, :infinity),
      max_queued_events_per_session: Keyword.get(opts, :max_queued_events_per_session, :infinity)
    }

    with {:ok, backend_state} <- display_backend.init(display_backend_opts),
         {:ok, listener} <- SafeRPCTCP.listen(listen_opts),
         {:ok, connection_supervisor} <- DynamicSupervisor.start_link(strategy: :one_for_one) do
      state = %{
        listener: listener,
        connection_supervisor: connection_supervisor,
        connections: %{},
        negotiated_connections: MapSet.new(),
        display_backend: display_backend,
        display_backend_state: backend_state,
        sessions: %{},
        session_ttl: session_ttl,
        session_gc_interval: session_gc_interval,
        limits: limits
      }

      start_acceptor(listener)
      schedule_session_gc(state)
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_call(:port, _from, state) do
    {:reply, TCP.port(state.listener), state}
  end

  def handle_call({:dispatch, connection_id, request}, _from, state) do
    {reply, state} = dispatch(request, connection_id, state)
    {:reply, reply, state}
  end

  def handle_call({:dispatch, request}, _from, state) do
    {reply, state} = dispatch(request, :legacy, state)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info({:gpui_remote_accepted, socket}, state) do
    start_acceptor(state.listener)

    connection_id = System.unique_integer([:positive])

    {:ok, owner} =
      ConnectionOwner.start_link(server: self(), connection_id: connection_id)

    child_spec = %{
      id: {Connection, connection_id},
      start:
        {Connection, :start_link,
         [
           [
             owner: owner,
             transport: SafeRPCTCP,
             socket: socket,
             recv_timeout: 5_000
           ]
         ]},
      restart: :temporary
    }

    {:ok, pid} = DynamicSupervisor.start_child(state.connection_supervisor, child_spec)
    Process.monitor(pid)

    {:noreply, put_in(state.connections[pid], %{socket: socket, owner: owner, id: connection_id})}
  end

  def handle_info({:gpui_remote_accept_error, reason}, state) do
    {:stop, {:accept_failed, reason}, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {connection, connections} = Map.pop(state.connections, pid)

    if connection && Process.alive?(connection.owner) do
      GenServer.stop(connection.owner)
    end

    state = %{state | connections: connections}

    state =
      if connection do
        update_in(state.negotiated_connections, &MapSet.delete(&1, connection.id))
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(:gc_sessions, state) do
    state = gc_sessions(state)
    schedule_session_gc(state)
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    SafeRPCTCP.close(state.listener)
    Supervisor.stop(state.connection_supervisor)
  end

  defp dispatch(%{cap: cap}, _connection_id, state) when cap not in [nil, @display_capability] do
    {{:error, :unauthorized}, state}
  end

  defp dispatch(%{kind: :call, op: :hello, payload: payload} = request, connection_id, state) do
    session_id = session_id(request)
    state = touch_session(state, session_id)
    dispatch_call(:hello, payload, session_id, connection_id, state)
  end

  defp dispatch(%{kind: :call, op: op, payload: payload} = request, connection_id, state) do
    session_id = session_id(request)
    state = touch_session(state, session_id)

    cond do
      not connection_negotiated?(state, connection_id) ->
        {{:error, :handshake_required}, state}

      DisplayProtocol.known_op?(op) ->
        dispatch_call(op, payload, session_id, state)

      true ->
        {{:error, {:unsupported_op, op}}, state}
    end
  end

  defp dispatch(%{kind: :cast, op: :event, payload: event} = request, connection_id, state) do
    session_id = session_id(request)
    state = touch_session(state, session_id)

    if connection_negotiated?(state, connection_id) do
      case push_event(state, session_id, event) do
        {:ok, state} -> {{:ok, :noreply}, state}
        {:error, reason} -> {{:error, reason}, state}
      end
    else
      {{:error, :handshake_required}, state}
    end
  end

  defp dispatch(_request, _connection_id, state), do: {{:error, :unsupported_request}, state}

  defp dispatch_call(:hello, payload, session_id, connection_id, state) do
    case DisplayProtocol.negotiate(payload) do
      {:ok, reply} -> {{:ok, reply}, mark_connection_negotiated(state, connection_id, session_id)}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:ping, _payload, _session_id, state) do
    {{:ok, %{pong: true}}, state}
  end

  defp dispatch_call(:resume_session, %{session_id: session_id}, _request_session_id, state) do
    state = ensure_session(state, session_id)
    session = Map.fetch!(state.sessions, session_id)

    {{:ok, %{session_id: session_id, windows: Map.values(session.windows)}}, state}
  end

  defp dispatch_call(:open_window, %{id: window_id} = window_payload, session_id, state) do
    with :ok <- check_window_quota(state, session_id, window_id),
         :ok <- state.display_backend.open_window(state.display_backend_state, window_payload) do
      {{:ok, %{}}, put_session_window(state, session_id, window_id, window_payload)}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:update_window, %{window_id: window_id, tree: tree}, session_id, state) do
    if session_has_window?(state, session_id, window_id) do
      case state.display_backend.update_window(state.display_backend_state, window_id, tree) do
        :ok ->
          state = put_session_window_tree(state, session_id, window_id, tree)

          case push_event(state, session_id, %{type: :window_updated, window_id: window_id}) do
            {:ok, state} -> {{:ok, %{}}, state}
            {:error, reason} -> {{:error, reason}, state}
          end

        {:error, reason} ->
          {{:error, reason}, state}
      end
    else
      {{:error, :unknown_window}, state}
    end
  end

  defp dispatch_call(:put_resource, %{id: resource_id, resource: resource}, session_id, state) do
    case check_resource_quota(state, session_id, resource_id, resource) do
      :ok -> {{:ok, %{}}, put_session_resource(state, session_id, resource_id, resource)}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:drop_resource, %{id: resource_id}, session_id, state) do
    {{:ok, %{}}, drop_session_resource(state, session_id, resource_id)}
  end

  defp dispatch_call(:drain_events, _payload, session_id, state) do
    events = session_events(state, session_id)
    {{:ok, %{events: Enum.reverse(events)}}, clear_session_events(state, session_id)}
  end

  defp dispatch_call(:event, event, session_id, state) do
    case push_event(state, session_id, event) do
      {:ok, state} -> {{:ok, %{}}, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp session_id(%{meta: %{session_id: session_id}}), do: session_id
  defp session_id(_request), do: :default

  defp schedule_session_gc(%{session_gc_interval: :infinity}), do: :ok

  defp schedule_session_gc(%{session_gc_interval: interval})
       when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :gc_sessions, interval)
    :ok
  end

  defp gc_sessions(%{session_ttl: :infinity} = state), do: state

  defp gc_sessions(%{session_ttl: ttl} = state) when is_integer(ttl) and ttl >= 0 do
    now = monotonic_ms()

    update_in(state.sessions, fn sessions ->
      Map.reject(sessions, fn {_session_id, session} -> now - session.last_seen > ttl end)
    end)
  end

  defp touch_session(state, session_id) do
    now = monotonic_ms()

    update_in(state.sessions, fn sessions ->
      Map.update(sessions, session_id, %{empty_session() | last_seen: now}, fn session ->
        %{session | last_seen: now}
      end)
    end)
  end

  defp connection_negotiated?(state, connection_id) do
    MapSet.member?(state.negotiated_connections, connection_id)
  end

  defp mark_connection_negotiated(state, connection_id, session_id) do
    state
    |> update_in([:negotiated_connections], &MapSet.put(&1, connection_id))
    |> update_in([:sessions], fn sessions ->
      Map.update(sessions, session_id, empty_session(), fn session -> session end)
    end)
  end

  defp check_window_quota(state, session_id, window_id) do
    session = Map.get(state.sessions, session_id, empty_session())

    if Map.has_key?(session.windows, window_id) do
      :ok
    else
      check_limit(:max_windows_per_session, map_size(session.windows), state.limits)
    end
  end

  defp check_resource_quota(state, session_id, resource_id, resource) do
    session = Map.get(state.sessions, session_id, empty_session())
    adding_resource? = not Map.has_key?(session.resources, resource_id)

    with :ok <-
           maybe_check_limit(
             adding_resource?,
             :max_resources_per_session,
             map_size(session.resources),
             state.limits
           ) do
      projected_bytes = session_resource_bytes(session, resource_id, resource)

      check_limit(:max_resource_bytes_per_session, projected_bytes, state.limits,
        inclusive?: true
      )
    end
  end

  defp maybe_check_limit(false, _key, _current, _limits), do: :ok
  defp maybe_check_limit(true, key, current, limits), do: check_limit(key, current, limits)

  defp check_event_quota(state, session_id) do
    session = Map.get(state.sessions, session_id, empty_session())
    check_limit(:max_queued_events_per_session, length(session.events), state.limits)
  end

  defp check_limit(key, current, limits, opts \\ []) do
    case Map.fetch!(limits, key) do
      :infinity ->
        :ok

      limit when is_integer(limit) and limit >= 0 ->
        over? =
          if Keyword.get(opts, :inclusive?, false), do: current > limit, else: current >= limit

        if over?, do: {:error, key}, else: :ok
    end
  end

  defp session_resource_bytes(session, resource_id, resource) do
    session.resources
    |> Map.put(resource_id, resource)
    |> Map.values()
    |> Enum.reduce(0, &(&2 + resource_bytes(&1)))
  end

  defp resource_bytes(%{data: data}) when is_binary(data), do: byte_size(data)
  defp resource_bytes(%{"data" => data}) when is_binary(data), do: byte_size(data)
  defp resource_bytes(resource), do: :erlang.external_size(resource)

  defp session_events(state, session_id) do
    state.sessions |> Map.get(session_id, empty_session()) |> Map.fetch!(:events)
  end

  defp clear_session_events(state, session_id) do
    update_in(state.sessions, fn sessions ->
      Map.update(sessions, session_id, empty_session(), &%{&1 | events: []})
    end)
  end

  defp push_event(state, session_id, event) do
    with :ok <- check_event_quota(state, session_id) do
      {:ok,
       update_in(state.sessions, fn sessions ->
         Map.update(sessions, session_id, %{empty_session() | events: [event]}, fn session ->
           update_in(session.events, &[event | &1])
         end)
       end)}
    end
  end

  defp ensure_session(state, session_id) do
    update_in(state.sessions, fn sessions ->
      Map.put_new(sessions, session_id, empty_session())
    end)
  end

  defp session_has_window?(state, session_id, window_id) do
    state.sessions
    |> Map.get(session_id, empty_session())
    |> Map.fetch!(:windows)
    |> Map.has_key?(window_id)
  end

  defp put_session_window(state, session_id, window_id, window_payload) do
    update_in(state.sessions, fn sessions ->
      Map.update(
        sessions,
        session_id,
        put_in(empty_session(), [:windows, window_id], window_payload),
        fn session ->
          put_in(session, [:windows, window_id], window_payload)
        end
      )
    end)
  end

  defp put_session_resource(state, session_id, resource_id, resource) do
    update_in(state.sessions, fn sessions ->
      Map.update(
        sessions,
        session_id,
        put_in(empty_session(), [:resources, resource_id], resource),
        fn session ->
          put_in(session, [:resources, resource_id], resource)
        end
      )
    end)
  end

  defp drop_session_resource(state, session_id, resource_id) do
    update_in(state.sessions, fn sessions ->
      Map.update(sessions, session_id, empty_session(), fn session ->
        update_in(session.resources, &Map.delete(&1, resource_id))
      end)
    end)
  end

  defp put_session_window_tree(state, session_id, window_id, tree) do
    update_in(state.sessions, fn sessions ->
      Map.update(sessions, session_id, empty_session(), fn session ->
        update_in(session.windows, fn windows ->
          Map.update(windows, window_id, %{id: window_id, root: %{tree: tree}}, fn window ->
            root = Map.get(window, :root) || %{}
            Map.put(window, :root, Map.put(root, :tree, tree))
          end)
        end)
      end)
    end)
  end

  defp empty_session,
    do: %{events: [], windows: %{}, resources: %{}, negotiated: false, last_seen: monotonic_ms()}

  defp monotonic_ms, do: System.monotonic_time(:millisecond)

  defp start_acceptor(listener) do
    owner = self()

    Task.start(fn ->
      case SafeRPCTCP.accept(listener, :infinity) do
        {:ok, socket} ->
          :ok = TCP.controlling_process(socket, owner)
          send(owner, {:gpui_remote_accepted, socket})

        {:error, reason} ->
          send(owner, {:gpui_remote_accept_error, reason})
      end
    end)
  end
end
