defmodule GPUI.Backend.RemoteTCP do
  @moduledoc """
  Remote display backend over framed TCP or SSL.

  This backend lets `GPUI.Runtime` send rendered windows/updates to a
  `GPUI.Remote.DisplayServer` process. The module name intentionally uses
  `TCP` as an acronym.
  """

  @behaviour GPUI.Backend

  alias GPUI.Protocol.Envelope
  alias GPUI.Remote.Transport
  alias GPUI.Remote.Transport.TCP

  @impl GPUI.Backend
  def init(opts) do
    connect_opts = [
      host: Keyword.get(opts, :host, "127.0.0.1"),
      port: Keyword.fetch!(opts, :port),
      ssl: Keyword.get(opts, :ssl, false),
      timeout: Keyword.get(opts, :timeout, 5_000)
    ]

    with {:ok, conn} <- TCP.connect(connect_opts),
         {:ok, _hello} <- request(conn, :hello, %{role: :runtime, capabilities: [:runtime_v1]}) do
      {:ok, %{conn: conn}}
    end
  end

  @impl GPUI.Backend
  def open_window(%{conn: conn}, window_payload) do
    with {:ok, _payload} <- request(conn, :open_window, window_payload), do: :ok
  end

  @impl GPUI.Backend
  def update_window(%{conn: conn}, window_id, tree) do
    with {:ok, _payload} <- request(conn, :update_window, %{window_id: window_id, tree: tree}),
         do: :ok
  end

  @impl GPUI.Backend
  def drain_events(%{conn: conn}) do
    with {:ok, %{events: events}} <- request(conn, :drain_events, %{}) do
      {:ok, events}
    end
  end

  @impl GPUI.Backend
  def emit_test_event(%{conn: conn}, event) do
    request(conn, :event, normalize_test_event(event))
  end

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled

  defp request(conn, op, payload) do
    envelope = Envelope.request(op, payload)

    with :ok <- Transport.send(conn, envelope),
         {:ok, response} <- Transport.recv(conn) do
      decode_response(response)
    end
  end

  defp decode_response(%{kind: :response, status: :ok, payload: payload}), do: {:ok, payload}
  defp decode_response(%{kind: :response, status: :error, reason: reason}), do: {:error, reason}
  defp decode_response(other), do: {:error, {:unexpected_response, other}}

  defp normalize_test_event(%{type: _type} = event), do: event

  defp normalize_test_event(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  defp normalize_test_event(event), do: event
end
