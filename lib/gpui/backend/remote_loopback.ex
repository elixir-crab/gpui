defmodule GPUI.Backend.RemoteLoopback do
  @moduledoc """
  In-memory remote backend simulation.

  This backend speaks `GPUI.Remote.DisplayProtocol` to a loopback server process. It is
  intentionally transport-shaped even though it runs in the same BEAM, so tests
  can validate the remote architecture before adding SSH/TCP/OTP distribution.
  """

  @behaviour GPUI.Backend

  alias GPUI.Backend.RemoteLoopback.Server
  alias GPUI.Remote.DisplayProtocol

  @impl GPUI.Backend
  def init(opts) do
    case Keyword.fetch(opts, :server) do
      {:ok, server} ->
        {:ok, %{server: server}}

      :error ->
        with {:ok, server} <- Server.start_link(opts) do
          {:ok, %{server: server}}
        end
    end
  end

  @impl GPUI.Backend
  def open_window(%{server: server}, window_payload) do
    :ok = Server.request(server, DisplayProtocol.open_window(window_payload))
  end

  @impl GPUI.Backend
  def update_window(%{server: server}, window_id, tree) do
    :ok = Server.request(server, DisplayProtocol.update_window(window_id, tree))
  end

  @impl GPUI.Backend
  def drain_events(%{server: server}) do
    Server.request(server, DisplayProtocol.drain_events())
  end

  @impl GPUI.Backend
  def emit_test_event(%{server: server}, event) do
    Server.request(server, DisplayProtocol.event(normalize_test_event(event)))
  end

  defp normalize_test_event(%{type: _type} = event), do: event

  defp normalize_test_event(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  defp normalize_test_event(event), do: event

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled
end
