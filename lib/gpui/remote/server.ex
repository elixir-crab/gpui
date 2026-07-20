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
  alias GPUI.Remote.SessionRegistry
  alias GPUI.Remote.SessionSupervisor
  alias GPUI.Remote.Transport.TCP

  @capability Protocol.capability()
  @default_connection_request_limit 64
  @default_session_request_limit 16
  @maximum_request_limit 4_096

  def child_spec(opts), do: GPUI.Remote.child_spec(__MODULE__, opts)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  def port(server), do: GenServer.call(server, :port)

  @impl GenServer
  def init(opts) do
    listen_opts = [port: Keyword.get(opts, :port, 0), ssl: Keyword.get(opts, :ssl, false)]

    with {:ok, connection_request_limit} <-
           request_limit(
             opts,
             :max_in_flight_requests_per_connection,
             @default_connection_request_limit
           ),
         {:ok, session_request_limit} <-
           request_limit(
             opts,
             :max_in_flight_requests_per_session,
             @default_session_request_limit
           ),
         {:ok, listener} <- TCP.listen(listen_opts),
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
        session_ttl: Keyword.get(opts, :session_ttl, :timer.minutes(30)),
        connection_request_limit: connection_request_limit,
        session_request_limit: session_request_limit
      }

      Acceptor.start(listener)
      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
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
      delegate_existing(state, session_id, :mount)
    else
      start_mounted_session(state, session_id, request_id, payload)
    end
  end

  defp dispatch_call(:resume_session, %{session_id: session_id}, state),
    do: delegate_existing(state, session_id, :resume)

  defp dispatch_call(:snapshot, %{session_id: session_id}, state),
    do: delegate_existing(state, session_id, :snapshot)

  defp dispatch_call(:event, %{session_id: session_id} = event, state),
    do: delegate_existing(state, session_id, {:event, event})

  defp dispatch_call(op, _payload, state), do: {{:error, {:invalid_payload, op}}, state}

  defp start_mounted_session(state, session_id, request_id, payload) do
    state = drop_session(state, session_id)

    opts = [
      app: state.app,
      args: Map.get(payload, :args, state.app_args),
      session_id: session_id,
      ttl: state.session_ttl,
      request_limit: state.session_request_limit
    ]

    case SessionSupervisor.start_session(state.session_supervisor, opts) do
      {:ok, session} -> register_session(state, session_id, request_id, session)
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp register_session(state, session_id, request_id, session) do
    case GPUI.Remote.Session.route(session) do
      {:ok, route} ->
        monitor = Process.monitor(session)

        registry =
          SessionRegistry.put(
            state.session_registry,
            session_id,
            session,
            route,
            monitor,
            request_id
          )

        {{:delegate, route, :mount}, %{state | session_registry: registry}}

      {:error, reason} ->
        SessionSupervisor.stop_session(session)
        {{:error, reason}, state}
    end
  end

  defp delegate_existing(state, session_id, request) do
    case SessionRegistry.fetch(state.session_registry, session_id) do
      {:ok, route} -> {{:delegate, route, request}, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp drop_session(state, session_id) do
    registry = SessionRegistry.drop(state.session_registry, session_id)

    %{state | session_registry: registry}
  end

  defp stop_supervisor(supervisor) do
    if Process.alive?(supervisor), do: Supervisor.stop(supervisor)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp request_limit(opts, name, default) do
    case Keyword.get(opts, name, default) do
      limit when is_integer(limit) and limit > 0 and limit <= @maximum_request_limit ->
        {:ok, limit}

      _invalid ->
        {:error, {:invalid_option, name}}
    end
  end

  defp negotiated?(state, connection_id),
    do: MapSet.member?(state.negotiated_connections, connection_id)

  defp mark_negotiated(state, connection_id) do
    update_in(state.negotiated_connections, &MapSet.put(&1, connection_id))
  end
end
