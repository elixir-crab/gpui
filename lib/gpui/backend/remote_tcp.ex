defmodule GPUI.Backend.RemoteTCP do
  @moduledoc """
  Remote display backend over framed TCP or SSL.

  RPC mechanics are delegated to `SafeRPC`; GPUI only defines the display
  operations and payloads.
  """

  @behaviour GPUI.Backend

  alias GPUI.Remote.DisplayProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  @impl GPUI.Backend
  def init(opts) do
    opts =
      opts
      |> Keyword.put(:transport, SafeRPCTCP)
      |> Keyword.put_new(:cap, DisplayProtocol.capability())

    with {:ok, client} <- SafeRPC.Client.start_link(opts),
         %{op: op, payload: payload} = DisplayProtocol.hello(),
         {:ok, _hello} <- SafeRPC.call(client, op, payload) do
      {:ok, %{client: client}}
    end
  end

  @impl GPUI.Backend
  def open_window(%{client: client}, window_payload) do
    %{op: op, payload: payload} = DisplayProtocol.open_window(window_payload)
    with {:ok, _payload} <- SafeRPC.call(client, op, payload), do: :ok
  end

  @impl GPUI.Backend
  def update_window(%{client: client}, window_id, tree) do
    %{op: op, payload: payload} = DisplayProtocol.update_window(window_id, tree)
    with {:ok, _payload} <- SafeRPC.call(client, op, payload), do: :ok
  end

  @impl GPUI.Backend
  def drain_events(%{client: client}) do
    %{op: op, payload: payload} = DisplayProtocol.drain_events()

    with {:ok, %{events: events}} <- SafeRPC.call(client, op, payload) do
      {:ok, events}
    end
  end

  @impl GPUI.Backend
  def emit_test_event(%{client: client}, event) do
    %{op: op, payload: payload} = event |> normalize_test_event() |> DisplayProtocol.event()
    SafeRPC.call(client, op, payload)
  end

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled

  defp normalize_test_event(%{type: _type} = event), do: event

  defp normalize_test_event(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  defp normalize_test_event(event), do: event
end
