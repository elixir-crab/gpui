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
        sessions: %{},
        negotiated_connections: MapSet.new(),
        session_ttl: session_ttl,
        session_gc_interval: gc_interval
      }

      Acceptor.start(listener)
      schedule_session_gc(state)
      {:ok, state}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    TCP.close(state.listener)
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

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, Connection.remove(state, pid)}
  end

  def handle_info(:gc_sessions, state) do
    state = gc_sessions(state)
    schedule_session_gc(state)
    {:noreply, state}
  end

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
    args = Map.get(payload, :args, state.app_args)
    state = drop_session(state, session_id)

    case SessionSupervisor.start_session(state.session_supervisor, app: state.app, args: args) do
      {:ok, session} ->
        entry = %{pid: session, last_seen: SessionGC.monotonic_ms()}
        state = put_in(state.sessions[session_id], entry)
        {{:ok, %{session_id: session_id, snapshot: GPUI.Session.snapshot(session)}}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_call(:resume_session, %{session_id: session_id}, state) do
    case fetch_session(state, session_id) do
      {:ok, session} ->
        state = touch_session(state, session_id)

        {{:ok,
          %{session_id: session_id, resumed: true, snapshot: GPUI.Session.snapshot(session)}},
         state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_call(:snapshot, %{session_id: session_id}, state) do
    case fetch_session(state, session_id) do
      {:ok, session} ->
        state = touch_session(state, session_id)
        {{:ok, %{snapshot: GPUI.Session.snapshot(session)}}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_call(:event, %{session_id: session_id} = event, state) do
    case fetch_session(state, session_id) do
      {:ok, session} ->
        {_event, snapshot} =
          GPUI.Session.dispatch_event(session, Map.delete(event, :session_id))

        state = touch_session(state, session_id)
        {{:ok, %{snapshot: snapshot}}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_call(op, _payload, state), do: {{:error, {:invalid_payload, op}}, state}

  defp fetch_session(state, session_id) do
    case Map.fetch(state.sessions, session_id) do
      {:ok, %{pid: session}} when is_pid(session) ->
        if Process.alive?(session), do: {:ok, session}, else: {:error, :session_expired}

      :error ->
        {:error, :unknown_session}
    end
  end

  defp drop_session(state, session_id) do
    case Map.pop(state.sessions, session_id) do
      {nil, _sessions} ->
        state

      {%{pid: session}, sessions} ->
        SessionSupervisor.stop_session(state.session_supervisor, session)
        %{state | sessions: sessions}
    end
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
    update_in(state.sessions, &SessionGC.touch_existing(&1, session_id))
  end

  defp schedule_session_gc(%{session_gc_interval: interval}) do
    SessionGC.schedule(interval, :gc_sessions)
  end

  defp gc_sessions(state) do
    sessions =
      SessionGC.reject_expired(state.sessions, state.session_ttl, fn _session_id, session ->
        SessionSupervisor.stop_session(state.session_supervisor, session.pid)
      end)

    %{state | sessions: sessions}
  end
end
