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

    session_id = Keyword.get_lazy(opts, :session_id, &new_session_id/0)

    with {:ok, client} <- SafeRPC.Client.start_link(opts),
         %{op: op, payload: payload} = DisplayProtocol.hello(),
         {:ok, _hello} <- call(client, session_id, op, payload) do
      {:ok, %{client: client, session_id: session_id}}
    end
  end

  @impl GPUI.Backend
  def open_window(%{client: client, session_id: session_id}, window_payload) do
    %{op: op, payload: payload} = DisplayProtocol.open_window(window_payload)
    with {:ok, _payload} <- call(client, session_id, op, payload), do: :ok
  end

  @impl GPUI.Backend
  def update_window(%{client: client, session_id: session_id}, window_id, tree) do
    %{op: op, payload: payload} = DisplayProtocol.update_window(window_id, tree)
    with {:ok, _payload} <- call(client, session_id, op, payload), do: :ok
  end

  @impl GPUI.Backend
  def drain_events(%{client: client, session_id: session_id}) do
    %{op: op, payload: payload} = DisplayProtocol.drain_events()

    with {:ok, %{events: events}} <- call(client, session_id, op, payload) do
      {:ok, events}
    end
  end

  @impl GPUI.Backend
  def emit_test_event(%{client: client, session_id: session_id}, event) do
    %{op: op, payload: payload} = event |> normalize_test_event() |> DisplayProtocol.event()
    call(client, session_id, op, payload)
  end

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled

  defp call(client, session_id, op, payload) do
    SafeRPC.call(client, op, payload, meta: %{session_id: session_id})
  end

  defp new_session_id do
    System.unique_integer([:positive, :monotonic])
  end

  defp normalize_test_event(%{type: _type} = event), do: event

  defp normalize_test_event(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  defp normalize_test_event(event), do: event
end
