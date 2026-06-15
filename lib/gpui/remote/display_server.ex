defmodule GPUI.Remote.DisplayServer do
  @moduledoc """
  Remote display endpoint for GPUI runtime protocol messages.

  The server accepts a framed TCP/SSL connection, receives
  `GPUI.Protocol.Envelope` messages, and dispatches display operations to a
  local `GPUI.Backend` implementation. This is the first real remote-display
  shape: an application runtime can send rendered window trees over a transport
  to a display process.
  """

  use GenServer

  alias GPUI.Protocol.Envelope
  alias GPUI.Remote.Transport
  alias GPUI.Remote.Transport.TCP

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

    with {:ok, backend_state} <- display_backend.init(display_backend_opts),
         {:ok, listener} <-
           TCP.listen(port: Keyword.get(opts, :port, 0), ssl: Keyword.get(opts, :ssl, false)) do
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

  def handle_call({:dispatch, envelope}, _from, state) do
    dispatch_envelope(envelope, state)
  end

  @impl GenServer
  def handle_info({:gpui_remote_accepted, conn}, state) do
    start_acceptor(state.listener)
    receiver = start_receiver(self(), conn)
    {:noreply, put_in(state.connections[receiver], conn)}
  end

  def handle_info({:gpui_remote_accept_error, reason}, state) do
    {:stop, {:accept_failed, reason}, state}
  end

  def handle_info({:gpui_remote_recv_closed, receiver}, state) do
    {:noreply, update_in(state.connections, &Map.delete(&1, receiver))}
  end

  def handle_info({:gpui_remote_recv_error, receiver, _reason}, state) do
    {:noreply, update_in(state.connections, &Map.delete(&1, receiver))}
  end

  defp dispatch_envelope(%{kind: :request, id: id, op: op, payload: payload}, state) do
    case dispatch_request(op, payload, state) do
      {:ok, payload, state} ->
        {:reply, {:reply, Envelope.ok(id, payload, op: op)}, state}

      {:error, reason, state} ->
        {:reply, {:reply, Envelope.error(id, reason, %{}, op: op)}, state}
    end
  end

  defp dispatch_envelope(%{kind: :event, op: :event, payload: event}, state) do
    {:reply, :noreply, push_event(state, event)}
  end

  defp dispatch_envelope(%{id: id}, state) do
    {:reply, {:reply, Envelope.error(id, :unsupported_envelope)}, state}
  end

  defp dispatch_request(:hello, _payload, state) do
    {:ok, %{version: 1, capabilities: [:runtime_v1, :display_server]}, state}
  end

  defp dispatch_request(:open_window, window_payload, state) do
    case state.display_backend.open_window(state.display_backend_state, window_payload) do
      :ok -> {:ok, %{}, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp dispatch_request(:update_window, %{window_id: window_id, tree: tree}, state) do
    case state.display_backend.update_window(state.display_backend_state, window_id, tree) do
      :ok ->
        state = push_event(state, %{type: :window_updated, window_id: window_id})
        {:ok, %{}, state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp dispatch_request(:drain_events, _payload, state) do
    {:ok, %{events: Enum.reverse(state.events)}, %{state | events: []}}
  end

  defp dispatch_request(:event, event, state) do
    {:ok, %{}, push_event(state, event)}
  end

  defp dispatch_request(op, _payload, state), do: {:error, {:unsupported_op, op}, state}

  defp push_event(state, event), do: update_in(state.events, &[event | &1])

  defp start_acceptor(listener) do
    owner = self()

    Task.start(fn ->
      case TCP.accept(listener) do
        {:ok, conn} ->
          :ok = TCP.controlling_process(conn, owner)
          send(owner, {:gpui_remote_accepted, conn})

        {:error, reason} ->
          send(owner, {:gpui_remote_accept_error, reason})
      end
    end)
  end

  defp start_receiver(server, conn) do
    {:ok, receiver} =
      Task.start(fn ->
        receive do
          :start_receiving -> receive_loop(server, conn)
        end
      end)

    :ok = TCP.controlling_process(conn, receiver)
    send(receiver, :start_receiving)
    receiver
  end

  defp receive_loop(server, conn) do
    case Transport.recv(conn, :infinity) do
      {:ok, envelope} ->
        case GenServer.call(server, {:dispatch, envelope}, :infinity) do
          {:reply, response} -> :ok = Transport.send(conn, response)
          :noreply -> :ok
        end

        receive_loop(server, conn)

      {:error, :closed} ->
        send(server, {:gpui_remote_recv_closed, self()})

      {:error, reason} ->
        send(server, {:gpui_remote_recv_error, self(), reason})
    end
  end
end
