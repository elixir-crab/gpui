defmodule GPUI.Backend.RemoteTCP do
  @moduledoc """
  Remote display backend over framed TCP or SSL.

  RPC mechanics are delegated to `SafeRPC`; GPUI only defines the display
  operations and payloads.
  """

  @behaviour GPUI.Backend

  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  @impl GPUI.Backend
  def init(opts) do
    opts =
      opts
      |> Keyword.put(:transport, SafeRPCTCP)
      |> Keyword.put_new(:cap, :gpui_display)

    with {:ok, client} <- SafeRPC.Client.start_link(opts),
         {:ok, _hello} <-
           SafeRPC.call(client, :hello, %{role: :runtime, capabilities: [:runtime_v1]}) do
      {:ok, %{client: client}}
    end
  end

  @impl GPUI.Backend
  def open_window(%{client: client}, window_payload) do
    with {:ok, _payload} <- SafeRPC.call(client, :open_window, window_payload), do: :ok
  end

  @impl GPUI.Backend
  def update_window(%{client: client}, window_id, tree) do
    with {:ok, _payload} <-
           SafeRPC.call(client, :update_window, %{window_id: window_id, tree: tree}),
         do: :ok
  end

  @impl GPUI.Backend
  def drain_events(%{client: client}) do
    with {:ok, %{events: events}} <- SafeRPC.call(client, :drain_events, %{}) do
      {:ok, events}
    end
  end

  @impl GPUI.Backend
  def emit_test_event(%{client: client}, event) do
    SafeRPC.call(client, :event, normalize_test_event(event))
  end

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled

  defp normalize_test_event(%{type: _type} = event), do: event

  defp normalize_test_event(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  defp normalize_test_event(event), do: event
end
