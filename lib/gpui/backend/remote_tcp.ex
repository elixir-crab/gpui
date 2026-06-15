defmodule GPUI.Backend.RemoteTCP do
  @moduledoc """
  Remote display backend over framed TCP or SSL.

  This backend lets `GPUI.Runtime` send rendered windows/updates to a
  `GPUI.Remote.DisplayServer` process. The module name intentionally uses
  `TCP` as an acronym.
  """

  @behaviour GPUI.Backend

  alias GPUI.Remote.ClientConnection

  @impl GPUI.Backend
  def init(opts) do
    with {:ok, conn} <- ClientConnection.start_link(opts),
         {:ok, _hello} <-
           ClientConnection.request(conn, :hello, %{role: :runtime, capabilities: [:runtime_v1]}) do
      {:ok, %{conn: conn}}
    end
  end

  @impl GPUI.Backend
  def open_window(%{conn: conn}, window_payload) do
    with {:ok, _payload} <- ClientConnection.request(conn, :open_window, window_payload), do: :ok
  end

  @impl GPUI.Backend
  def update_window(%{conn: conn}, window_id, tree) do
    with {:ok, _payload} <-
           ClientConnection.request(conn, :update_window, %{window_id: window_id, tree: tree}),
         do: :ok
  end

  @impl GPUI.Backend
  def drain_events(%{conn: conn}) do
    with {:ok, %{events: events}} <- ClientConnection.request(conn, :drain_events, %{}) do
      {:ok, events}
    end
  end

  @impl GPUI.Backend
  def emit_test_event(%{conn: conn}, event) do
    ClientConnection.request(conn, :event, normalize_test_event(event))
  end

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled

  defp normalize_test_event(%{type: _type} = event), do: event

  defp normalize_test_event(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  defp normalize_test_event(event), do: event
end
