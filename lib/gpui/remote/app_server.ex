defmodule GPUI.Remote.AppServer do
  @moduledoc """
  Remote OTP application endpoint for the inverted GPUI remote model.

  A local display client connects here, mounts a remote `GPUI.Application`, sends
  UI events, and receives rendered window snapshots back. SafeRPC handles the RPC
  mechanics; GPUI owns only app lifecycle operations.
  """

  use GenServer

  alias GPUI.Remote.AppProtocol
  alias GPUI.Remote.ConnectionOwner
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Server.Connection

  @app_capability AppProtocol.capability()

  def child_spec(opts) do
    %{id: Keyword.get(opts, :name, __MODULE__), start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  def port(server), do: GenServer.call(server, :port)

  @impl GenServer
  def init(opts) do
    app = Keyword.fetch!(opts, :app)
    listen_opts = [port: Keyword.get(opts, :port, 0), ssl: Keyword.get(opts, :ssl, false)]

    session_ttl =
      Keyword.get(opts, :app_session_ttl, Keyword.get(opts, :session_ttl, :timer.minutes(30)))

    session_gc_interval =
      Keyword.get(
        opts,
        :app_session_gc_interval,
        Keyword.get(opts, :session_gc_interval, :timer.minutes(1))
      )

    with {:ok, listener} <- SafeRPCTCP.listen(listen_opts),
         {:ok, connection_supervisor} <- DynamicSupervisor.start_link(strategy: :one_for_one) do
      state = %{
        app: app,
        app_args: Keyword.get(opts, :args, []),
        runtime: nil,
        listener: listener,
        connection_supervisor: connection_supervisor,
        connections: %{},
        sessions: %{},
        negotiated_connections: MapSet.new(),
        session_ttl: session_ttl,
        session_gc_interval: session_gc_interval
      }

      start_acceptor(listener)
      schedule_session_gc(state)
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_call(:port, _from, state), do: {:reply, TCP.port(state.listener), state}

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
         [[owner: owner, transport: SafeRPCTCP, socket: socket, recv_timeout: 5_000]]},
      restart: :temporary
    }

    {:ok, pid} = DynamicSupervisor.start_child(state.connection_supervisor, child_spec)
    Process.monitor(pid)
    {:noreply, put_in(state.connections[pid], %{socket: socket, owner: owner, id: connection_id})}
  end

  def handle_info({:gpui_remote_accept_error, reason}, state),
    do: {:stop, {:accept_failed, reason}, state}

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
    stop_runtime(state.runtime)
    SafeRPCTCP.close(state.listener)
    Supervisor.stop(state.connection_supervisor)
  end

  defp stop_runtime(nil), do: :ok

  defp stop_runtime(runtime) when is_pid(runtime) do
    if Process.alive?(runtime), do: GenServer.stop(runtime)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp dispatch(%{cap: cap}, _connection_id, state) when cap not in [nil, @app_capability],
    do: {{:error, :unauthorized}, state}

  defp dispatch(%{kind: :call, op: :hello, payload: payload}, connection_id, state) do
    dispatch_call(:hello, payload, connection_id, state)
  end

  defp dispatch(%{kind: :call, op: op, payload: payload}, connection_id, state) do
    cond do
      not connection_negotiated?(state, connection_id) ->
        {{:error, :handshake_required}, state}

      AppProtocol.known_op?(op) ->
        dispatch_call(op, payload, touch_session_from_payload(state, payload))

      true ->
        {{:error, {:unsupported_op, op}}, state}
    end
  end

  defp dispatch(_request, _connection_id, state), do: {{:error, :unsupported_request}, state}

  defp dispatch_call(:hello, payload, connection_id, state) do
    case AppProtocol.negotiate(payload) do
      {:ok, reply} -> {{:ok, reply}, mark_connection_negotiated(state, connection_id)}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:mount, payload, state) do
    args = Map.get(payload, :args, state.app_args)
    session_id = Map.get(payload, :session_id, :default)

    case ensure_runtime(%{state | app_args: args}) do
      {:ok, state} ->
        state =
          put_in(state.sessions[session_id], %{
            runtime: state.runtime,
            app_args: args,
            last_seen: monotonic_ms()
          })

        {{:ok, %{session_id: session_id, windows: snapshot(state)}}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_call(:resume_session, %{session_id: session_id}, state) do
    case Map.fetch(state.sessions, session_id) do
      {:ok, %{runtime: runtime}} when is_pid(runtime) ->
        if Process.alive?(runtime) do
          state = state |> Map.put(:runtime, runtime) |> touch_session(session_id)
          {{:ok, %{session_id: session_id, resumed: true, windows: snapshot(state)}}, state}
        else
          {{:error, :session_expired}, update_in(state.sessions, &Map.delete(&1, session_id))}
        end

      :error ->
        {{:error, :unknown_session}, state}
    end
  end

  defp dispatch_call(:snapshot, _payload, state) do
    case ensure_runtime(state) do
      {:ok, state} -> {{:ok, %{windows: snapshot(state)}}, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:event, event, state) do
    case ensure_runtime(state) do
      {:ok, %{runtime: runtime} = state} ->
        {_event, windows} = GPUI.Runtime.dispatch_event(runtime, event)
        {{:ok, %{windows: windows}}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp ensure_runtime(%{runtime: runtime} = state) when is_pid(runtime) do
    if Process.alive?(runtime), do: {:ok, state}, else: start_runtime(%{state | runtime: nil})
  end

  defp ensure_runtime(state), do: start_runtime(state)

  defp start_runtime(state) do
    case GPUI.Runtime.start_link(app: state.app, args: state.app_args, backend: :data) do
      {:ok, runtime} -> {:ok, %{state | runtime: runtime}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp snapshot(%{runtime: runtime}) do
    runtime
    |> GPUI.Runtime.windows()
    |> Enum.map(&GPUI.Runtime.window_payload/1)
  end

  defp touch_session_from_payload(state, %{session_id: session_id}),
    do: touch_session(state, session_id)

  defp touch_session_from_payload(state, _payload), do: state

  defp connection_negotiated?(state, connection_id) do
    MapSet.member?(state.negotiated_connections, connection_id)
  end

  defp mark_connection_negotiated(state, connection_id) do
    update_in(state.negotiated_connections, &MapSet.put(&1, connection_id))
  end

  defp touch_session(state, session_id) do
    update_in(state.sessions, fn sessions ->
      if Map.has_key?(sessions, session_id) do
        update_in(sessions, [session_id], &Map.put(&1, :last_seen, monotonic_ms()))
      else
        sessions
      end
    end)
  end

  defp schedule_session_gc(%{session_gc_interval: :infinity}), do: :ok

  defp schedule_session_gc(%{session_gc_interval: interval})
       when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :gc_sessions, interval)
    :ok
  end

  defp gc_sessions(%{session_ttl: :infinity} = state), do: state

  defp gc_sessions(%{session_ttl: ttl} = state) when is_integer(ttl) and ttl >= 0 do
    now = monotonic_ms()

    {expired, active} =
      Enum.split_with(state.sessions, fn {_session_id, session} ->
        now - Map.get(session, :last_seen, now) > ttl
      end)

    Enum.each(expired, fn {_session_id, session} -> stop_runtime(Map.get(session, :runtime)) end)
    %{state | sessions: Map.new(active)}
  end

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
