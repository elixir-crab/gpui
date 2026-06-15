defmodule GPUI.Remote.DisplayServer do
  @moduledoc """
  Remote display endpoint for GPUI runtime protocol messages.

  The server accepts TCP/SSL connections and delegates per-client SafeRPC
  request decoding, worker management, replies, and safe ETF handling to
  `SafeRPC.Server.Connection`. GPUI owns only the display operations.
  """

  use GenServer

  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Server.Connection

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec port(GenServer.server()) :: {:ok, :inet.port_number()} | {:error, term()}
  def port(server), do: GenServer.call(server, :port)

  @impl GenServer
  def init(opts) do
    display_backend = opts |> Keyword.get(:display_backend, :data) |> GPUI.Backend.module_for()
    display_backend_opts = Keyword.get(opts, :display_backend_opts, [])

    listen_opts = [port: Keyword.get(opts, :port, 0), ssl: Keyword.get(opts, :ssl, false)]

    with {:ok, backend_state} <- display_backend.init(display_backend_opts),
         {:ok, listener} <- SafeRPCTCP.listen(listen_opts) do
      state = %{
        listener: listener,
        connections: %{},
        display_backend: display_backend,
        display_backend_state: backend_state,
        events: []
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

    {:ok, pid} =
      Connection.start_link(
        owner: self(),
        transport: SafeRPCTCP,
        socket: socket,
        recv_timeout: 5_000
      )

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
  end

  defp dispatch(%{cap: cap}, state) when cap not in [nil, :gpui_display] do
    {{:error, :unauthorized}, state}
  end

  defp dispatch(%{kind: :call, op: op, payload: payload}, state),
    do: dispatch_call(op, payload, state)

  defp dispatch(%{kind: :cast, op: :event, payload: event}, state) do
    {{:ok, :noreply}, push_event(state, event)}
  end

  defp dispatch(_request, state), do: {{:error, :unsupported_request}, state}

  defp dispatch_call(:hello, _payload, state) do
    {{:ok, %{version: 1, capabilities: [:runtime_v1, :display_server, :safe_rpc]}}, state}
  end

  defp dispatch_call(:open_window, window_payload, state) do
    case state.display_backend.open_window(state.display_backend_state, window_payload) do
      :ok -> {{:ok, %{}}, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:update_window, %{window_id: window_id, tree: tree}, state) do
    case state.display_backend.update_window(state.display_backend_state, window_id, tree) do
      :ok ->
        state = push_event(state, %{type: :window_updated, window_id: window_id})
        {{:ok, %{}}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_call(:drain_events, _payload, state) do
    {{:ok, %{events: Enum.reverse(state.events)}}, %{state | events: []}}
  end

  defp dispatch_call(:event, event, state) do
    {{:ok, %{}}, push_event(state, event)}
  end

  defp dispatch_call(op, _payload, state), do: {{:error, {:unsupported_op, op}}, state}

  defp push_event(state, event), do: update_in(state.events, &[event | &1])

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
