defmodule GPUI.Remote.Server do
  @moduledoc """
  SafeRPC endpoint for renderer-independent GPUI application sessions.

  Every remote session owns a distinct `GPUI.Session`. The server never starts a
  native display; rendering happens only on the connected display client.
  """

  use GenServer

  alias GPUI.Remote.Acceptor
  alias GPUI.Remote.Connection
  alias GPUI.Remote.Protocol
  alias GPUI.Remote.Request
  alias GPUI.Remote.SessionGC
  alias GPUI.Remote.SessionRegistry
  alias GPUI.Remote.SessionSupervisor
  alias GPUI.Remote.Transport.TCP

  @capability Protocol.capability()

  def child_spec(opts), do: GPUI.Remote.child_spec(__MODULE__, opts)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  def port(server), do: GenServer.call(server, :port)

  @impl GenServer
  def init(opts) do
    listen_opts = [port: Keyword.get(opts, :port, 0), ssl: Keyword.get(opts, :ssl, false)]

    session_ttl = Keyword.get(opts, :session_ttl, :timer.minutes(30))
    gc_interval = Keyword.get(opts, :session_gc_interval, :timer.minutes(1))

    with {:ok, listener} <- TCP.listen(listen_opts),
         {:ok, connection_supervisor} <- DynamicSupervisor.start_link(strategy: :one_for_one),
         {:ok, session_supervisor} <- SessionSupervisor.start_link() do
      state = %{
        app: Keyword.fetch!(opts, :app),
        app_args: Keyword.get(opts, :args, []),
        listener: listener,
        connection_supervisor: connection_supervisor,
        session_supervisor: session_supervisor,
        connections: %{},
        session_registry: SessionRegistry.new(),
        negotiated_connections: MapSet.new(),
        session_ttl: session_ttl,
        session_gc_interval: gc_interval,
        session_gc_timer: nil
      }

      Acceptor.start(listener)
      {:ok, schedule_session_gc(state)}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    TCP.close(state.listener)
    Connection.stop_all(state)
    stop_supervisor(state.connection_supervisor)
    stop_supervisor(state.session_supervisor)
  end

  @impl GenServer
  def handle_call(:port, _from, state) do
    {:reply, Connection.port(state), state}
  end

  def handle_call({:dispatch, connection_id, request}, _from, state) do
    {reply, state} = dispatch(request, connection_id, state)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info({:gpui_remote_accepted, socket}, state) do
    {:noreply, Connection.accept(state, socket)}
  end

  def handle_info({:gpui_remote_accept_error, reason}, state),
    do: {:stop, {:accept_failed, reason}, state}

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    state =
      case SessionRegistry.remove_down(state.session_registry, ref) do
        :error -> Connection.remove(state, pid)
        {:ok, _session_id, registry} -> %{state | session_registry: registry}
      end

    {:noreply, state}
  end

  def handle_info({:gc_sessions, token}, %{session_gc_timer: token} = state) do
    state = state |> Map.put(:session_gc_timer, nil) |> gc_sessions() |> schedule_session_gc()
    {:noreply, state}
  end

  def handle_info({:gc_sessions, _stale_token}, state), do: {:noreply, state}

  defp dispatch(request, connection_id, state) do
    Request.dispatch(request, connection_id, state, &dispatch_request/3)
  end

  defp dispatch_request(%Request{cap: cap}, _connection_id, state)
       when cap not in [nil, @capability],
       do: {{:error, :unauthorized}, state}

  defp dispatch_request(
         %Request{kind: :call, op: :hello, payload: payload},
         connection_id,
         state
       )
       when is_map(payload) do
    case Protocol.negotiate(payload) do
      {:ok, reply} -> {{:ok, reply}, mark_negotiated(state, connection_id)}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_request(%Request{kind: :call, op: op, payload: payload}, connection_id, state)
       when is_map(payload) do
    cond do
      not negotiated?(state, connection_id) ->
        {{:error, :handshake_required}, state}

      Protocol.known_op?(op) ->
        dispatch_call(op, payload, state)

      true ->
        {{:error, {:unsupported_op, op}}, state}
    end
  end

  defp dispatch_request(%Request{kind: :call, op: op}, _connection_id, state),
    do: {{:error, {:invalid_payload, op}}, state}

  defp dispatch_request(_request, _connection_id, state),
    do: {{:error, :unsupported_request}, state}

  defp dispatch_call(:mount, payload, state) do
    session_id = Map.get(payload, :session_id, :default)
    request_id = Map.get(payload, :request_id)

    if SessionRegistry.repeated_mount?(state.session_registry, session_id, request_id) do
      reply_with_existing_mount(state, session_id)
    else
      start_mounted_session(state, session_id, request_id, payload)
    end
  end

  defp dispatch_call(:resume_session, %{session_id: session_id}, state) do
    case fetch_session(state, session_id) do
      {:ok, session} -> resume_session(state, session_id, session)
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:snapshot, %{session_id: session_id}, state) do
    case fetch_session(state, session_id) do
      {:ok, session} -> session_snapshot(state, session_id, session)
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:event, %{session_id: session_id} = event, state) do
    case fetch_session(state, session_id) do
      {:ok, session} -> dispatch_session_event(state, session_id, session, event)
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(op, _payload, state), do: {{:error, {:invalid_payload, op}}, state}

  defp start_mounted_session(state, session_id, request_id, payload) do
    args = Map.get(payload, :args, state.app_args)
    state = drop_session(state, session_id)

    case SessionSupervisor.start_session(state.session_supervisor, app: state.app, args: args) do
      {:ok, session} -> mount_started_session(state, session_id, request_id, session)
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp mount_started_session(state, session_id, request_id, session) do
    case session_call(fn -> GPUI.Session.snapshot(session) end) do
      {:ok, snapshot} ->
        monitor = Process.monitor(session)

        registry =
          SessionRegistry.put(
            state.session_registry,
            session_id,
            session,
            monitor,
            request_id
          )

        {{:ok, %{session_id: session_id, snapshot: snapshot}},
         %{state | session_registry: registry}}

      {:error, reason} ->
        SessionSupervisor.stop_session(state.session_supervisor, session)
        {{:error, reason}, state}
    end
  end

  defp resume_session(state, session_id, session) do
    case session_call(fn -> GPUI.Session.snapshot(session) end) do
      {:ok, snapshot} ->
        state = touch_session(state, session_id)
        {{:ok, %{session_id: session_id, resumed: true, snapshot: snapshot}}, state}

      {:error, reason} ->
        {{:error, reason}, drop_session(state, session_id)}
    end
  end

  defp session_snapshot(state, session_id, session) do
    case session_call(fn -> GPUI.Session.snapshot(session) end) do
      {:ok, snapshot} ->
        {{:ok, %{snapshot: snapshot}}, touch_session(state, session_id)}

      {:error, reason} ->
        {{:error, reason}, drop_session(state, session_id)}
    end
  end

  defp dispatch_session_event(state, session_id, session, event) do
    request_id = Map.get(event, :request_id)

    if SessionRegistry.repeated_event?(state.session_registry, session_id, request_id) do
      session_snapshot(state, session_id, session)
    else
      apply_session_event(state, session_id, session, request_id, event)
    end
  end

  defp apply_session_event(state, session_id, session, request_id, event) do
    event = Map.drop(event, [:session_id, :request_id])

    case session_call(fn -> GPUI.Session.dispatch_event(session, event) end) do
      {:ok, {_event, snapshot}} ->
        state =
          state
          |> touch_session(session_id)
          |> remember_event(session_id, request_id)

        {{:ok, %{snapshot: snapshot}}, state}

      {:error, reason} ->
        {{:error, reason}, drop_session(state, session_id)}
    end
  end

  defp fetch_session(state, session_id),
    do: SessionRegistry.fetch(state.session_registry, session_id)

  defp drop_session(state, session_id) do
    registry =
      SessionRegistry.drop(state.session_registry, session_id, state.session_supervisor)

    %{state | session_registry: registry}
  end

  defp stop_supervisor(supervisor) do
    if Process.alive?(supervisor), do: Supervisor.stop(supervisor)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp negotiated?(state, connection_id),
    do: MapSet.member?(state.negotiated_connections, connection_id)

  defp mark_negotiated(state, connection_id) do
    update_in(state.negotiated_connections, &MapSet.put(&1, connection_id))
  end

  defp touch_session(state, session_id) do
    registry = SessionRegistry.touch(state.session_registry, session_id)
    %{state | session_registry: registry}
  end

  defp schedule_session_gc(%{session_gc_interval: :infinity} = state), do: state

  defp schedule_session_gc(%{session_gc_interval: interval, session_gc_timer: nil} = state) do
    token = make_ref()
    :ok = SessionGC.schedule(interval, {:gc_sessions, token})
    %{state | session_gc_timer: token}
  end

  defp schedule_session_gc(state), do: state

  defp gc_sessions(state) do
    registry =
      SessionRegistry.gc(state.session_registry, state.session_ttl, state.session_supervisor)

    %{state | session_registry: registry}
  end

  defp reply_with_existing_mount(state, session_id) do
    %{pid: session} = SessionRegistry.entry!(state.session_registry, session_id)

    case session_call(fn -> GPUI.Session.snapshot(session) end) do
      {:ok, snapshot} ->
        {{:ok, %{session_id: session_id, snapshot: snapshot}}, touch_session(state, session_id)}

      {:error, reason} ->
        {{:error, reason}, drop_session(state, session_id)}
    end
  end

  defp remember_event(state, session_id, request_id) do
    registry = SessionRegistry.remember_event(state.session_registry, session_id, request_id)
    %{state | session_registry: registry}
  end

  defp session_call(callback) do
    {:ok, callback.()}
  catch
    :exit, reason -> {:error, {:session_unavailable, reason}}
  end
end
