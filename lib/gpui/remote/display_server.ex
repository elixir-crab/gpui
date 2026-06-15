defmodule GPUI.Remote.DisplayServer do
  @moduledoc """
  Remote display endpoint for GPUI runtime protocol messages.

  The server accepts TCP/SSL connections and delegates per-client SafeRPC
  request decoding, worker management, replies, and safe ETF handling to
  `SafeRPC.Server.Connection`. GPUI owns only the display operations.
  """

  use GenServer

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

    with {:ok, backend_state} <- display_backend.init(display_backend_opts),
         {:ok, listener} <- SafeRPCTCP.listen(listen_opts),
         {:ok, connection_supervisor} <- DynamicSupervisor.start_link(strategy: :one_for_one) do
      state = %{
        listener: listener,
        connection_supervisor: connection_supervisor,
        connections: %{},
        display_backend: display_backend,
        display_backend_state: backend_state,
        sessions: %{}
      }

      start_acceptor(listener)
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_call(:port, _from, state) do
    {:reply, TCP.port(state.listener), state}
  end

  def handle_call({:dispatch, request}, _from, state) do
    {reply, state} = dispatch(request, state)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info({:gpui_remote_accepted, socket}, state) do
    start_acceptor(state.listener)

    child_spec = %{
      id: {Connection, System.unique_integer([:positive])},
      start:
        {Connection, :start_link,
         [
           [
             owner: self(),
             transport: SafeRPCTCP,
             socket: socket,
             recv_timeout: 5_000
           ]
         ]},
      restart: :temporary
    }

    {:ok, pid} = DynamicSupervisor.start_child(state.connection_supervisor, child_spec)
    Process.monitor(pid)

    {:noreply, put_in(state.connections[pid], socket)}
  end

  def handle_info({:gpui_remote_accept_error, reason}, state) do
    {:stop, {:accept_failed, reason}, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, update_in(state.connections, &Map.delete(&1, pid))}
  end

  @impl GenServer
  def terminate(_reason, state) do
    SafeRPCTCP.close(state.listener)
    Supervisor.stop(state.connection_supervisor)
  end

  defp dispatch(%{cap: cap}, state) when cap not in [nil, @display_capability] do
    {{:error, :unauthorized}, state}
  end

  defp dispatch(%{kind: :call, op: op, payload: payload} = request, state) do
    if DisplayProtocol.known_op?(op) do
      dispatch_call(op, payload, session_id(request), state)
    else
      {{:error, {:unsupported_op, op}}, state}
    end
  end

  defp dispatch(%{kind: :cast, op: :event, payload: event} = request, state) do
    {{:ok, :noreply}, push_event(state, session_id(request), event)}
  end

  defp dispatch(_request, state), do: {{:error, :unsupported_request}, state}

  defp dispatch_call(:hello, _payload, _session_id, state) do
    {{:ok, %{version: 1, capabilities: [:runtime_v1, :display_server, :safe_rpc]}}, state}
  end

  defp dispatch_call(:open_window, %{id: window_id} = window_payload, session_id, state) do
    case state.display_backend.open_window(state.display_backend_state, window_payload) do
      :ok -> {{:ok, %{}}, put_session_window(state, session_id, window_id, window_payload)}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:update_window, %{window_id: window_id, tree: tree}, session_id, state) do
    if session_has_window?(state, session_id, window_id) do
      case state.display_backend.update_window(state.display_backend_state, window_id, tree) do
        :ok ->
          state =
            state
            |> put_session_window_tree(session_id, window_id, tree)
            |> push_event(session_id, %{type: :window_updated, window_id: window_id})

          {{:ok, %{}}, state}

        {:error, reason} ->
          {{:error, reason}, state}
      end
    else
      {{:error, :unknown_window}, state}
    end
  end

  defp dispatch_call(:drain_events, _payload, session_id, state) do
    events = session_events(state, session_id)
    {{:ok, %{events: Enum.reverse(events)}}, clear_session_events(state, session_id)}
  end

  defp dispatch_call(:event, event, session_id, state) do
    {{:ok, %{}}, push_event(state, session_id, event)}
  end

  defp session_id(%{meta: %{session_id: session_id}}), do: session_id
  defp session_id(_request), do: :default

  defp session_events(state, session_id) do
    state.sessions |> Map.get(session_id, empty_session()) |> Map.fetch!(:events)
  end

  defp clear_session_events(state, session_id) do
    update_in(state.sessions, fn sessions ->
      Map.update(sessions, session_id, empty_session(), &%{&1 | events: []})
    end)
  end

  defp push_event(state, session_id, event) do
    update_in(state.sessions, fn sessions ->
      Map.update(sessions, session_id, %{empty_session() | events: [event]}, fn session ->
        update_in(session.events, &[event | &1])
      end)
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

  defp empty_session, do: %{events: [], windows: %{}}

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
