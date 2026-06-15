defmodule GPUI.Remote.ClientConnection do
  @moduledoc """
  Client-side GPUI remote session over a framed transport connection.

  The process owns request correlation and pending-call timeouts. A dedicated
  receiver task owns passive socket reads and forwards envelopes back here.
  """

  use GenServer

  alias GPUI.Protocol.Envelope
  alias GPUI.Remote.Transport
  alias GPUI.Remote.Transport.TCP

  @type state :: %{
          conn: Transport.connection(),
          next_id: pos_integer(),
          pending: %{pos_integer() => {GenServer.from(), reference()}},
          events: [Envelope.t()],
          default_timeout: timeout()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec request(GenServer.server(), atom(), map(), timeout()) :: {:ok, map()} | {:error, term()}
  def request(server, op, payload \\ %{}, timeout \\ 5_000)
      when is_atom(op) and is_map(payload) do
    GenServer.call(server, {:request, op, payload, timeout}, call_timeout(timeout))
  end

  @spec event(GenServer.server(), atom(), map()) :: :ok | {:error, term()}
  def event(server, op, payload \\ %{}) when is_atom(op) and is_map(payload) do
    GenServer.call(server, {:event, op, payload})
  end

  @spec drain_events(GenServer.server()) :: [Envelope.t()]
  def drain_events(server), do: GenServer.call(server, :drain_events)

  @impl GenServer
  def init(opts) do
    connect_opts = [
      host: Keyword.get(opts, :host, "127.0.0.1"),
      port: Keyword.fetch!(opts, :port),
      ssl: Keyword.get(opts, :ssl, false),
      timeout: Keyword.get(opts, :timeout, 5_000)
    ]

    with {:ok, conn} <- TCP.connect(connect_opts) do
      start_receiver(self(), conn)

      {:ok,
       %{
         conn: conn,
         next_id: 1,
         pending: %{},
         events: [],
         default_timeout: Keyword.get(opts, :request_timeout, 5_000)
       }}
    end
  end

  @impl GenServer
  def handle_call({:request, op, payload, timeout}, from, state) do
    id = state.next_id
    envelope = Envelope.request(op, payload, id: id)

    case Transport.send(state.conn, envelope) do
      :ok ->
        timeout = normalize_timeout(timeout, state.default_timeout)
        timer = request_timer(id, timeout)

        {:noreply,
         %{
           state
           | next_id: id + 1,
             pending: Map.put(state.pending, id, {from, timer})
         }}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:event, op, payload}, _from, state) do
    case Transport.send(state.conn, Envelope.event(op, payload)) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:drain_events, _from, state) do
    {:reply, Enum.reverse(state.events), %{state | events: []}}
  end

  @impl GenServer
  def handle_info({:gpui_remote_envelope, envelope}, state) do
    envelope = Envelope.validate!(envelope)

    case envelope do
      %{kind: :response, id: id} ->
        reply_to_pending(id, envelope, state)

      %{kind: :event} ->
        {:noreply, update_in(state.events, &[envelope | &1])}

      _other ->
        {:noreply, state}
    end
  end

  def handle_info({:request_timeout, id}, state) do
    case Map.pop(state.pending, id) do
      {{from, _timer}, pending} ->
        GenServer.reply(from, {:error, :timeout})
        {:noreply, %{state | pending: pending}}

      {nil, _pending} ->
        {:noreply, state}
    end
  end

  def handle_info({:gpui_remote_recv_closed, _conn}, state) do
    {:stop, :closed, fail_pending(state, :closed)}
  end

  def handle_info({:gpui_remote_recv_error, _conn, reason}, state) do
    {:stop, {:recv_failed, reason}, fail_pending(state, reason)}
  end

  defp reply_to_pending(id, envelope, state) do
    case Map.pop(state.pending, id) do
      {{from, timer}, pending} ->
        cancel_timer(timer)
        GenServer.reply(from, decode_response(envelope))
        {:noreply, %{state | pending: pending}}

      {nil, _pending} ->
        {:noreply, state}
    end
  end

  defp decode_response(%{status: :ok, payload: payload}), do: {:ok, payload}
  defp decode_response(%{status: :error, reason: reason}), do: {:error, reason}
  defp decode_response(other), do: {:error, {:unexpected_response, other}}

  defp fail_pending(state, reason) do
    Enum.each(state.pending, fn {_id, {from, timer}} ->
      cancel_timer(timer)
      GenServer.reply(from, {:error, reason})
    end)

    %{state | pending: %{}}
  end

  defp call_timeout(:infinity), do: :infinity
  defp call_timeout(timeout) when is_integer(timeout) and timeout > 0, do: timeout + 1_000
  defp call_timeout(_timeout), do: 6_000

  defp request_timer(_id, :infinity), do: nil
  defp request_timer(id, timeout), do: Process.send_after(self(), {:request_timeout, id}, timeout)

  defp cancel_timer(nil), do: false
  defp cancel_timer(timer), do: Process.cancel_timer(timer)

  defp normalize_timeout(:infinity, _default_timeout), do: :infinity

  defp normalize_timeout(timeout, _default_timeout) when is_integer(timeout) and timeout > 0,
    do: timeout

  defp normalize_timeout(_timeout, default_timeout), do: default_timeout

  defp start_receiver(server, conn) do
    {:ok, receiver} =
      Task.start(fn ->
        receive do
          :start_receiving -> receive_loop(server, conn)
        end
      end)

    :ok = TCP.controlling_process(conn, receiver)
    send(receiver, :start_receiving)
    :ok
  end

  defp receive_loop(server, conn) do
    case Transport.recv(conn, :infinity) do
      {:ok, envelope} ->
        send(server, {:gpui_remote_envelope, envelope})
        receive_loop(server, conn)

      {:error, :closed} ->
        send(server, {:gpui_remote_recv_closed, conn})

      {:error, reason} ->
        send(server, {:gpui_remote_recv_error, conn, reason})
    end
  end
end
