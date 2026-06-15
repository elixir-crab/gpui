defmodule GPUI.Backend.RemoteTCP do
  @moduledoc """
  Remote display backend over framed TCP or SSL.

  RPC mechanics are delegated to `SafeRPC`; GPUI only defines the display
  operations and payloads. A backend session process owns reconnect/resume state
  and cached window payloads.
  """

  @behaviour GPUI.Backend

  alias GPUI.Backend.RemoteTCP.Session

  @impl GPUI.Backend
  def init(opts) do
    with {:ok, session} <- Session.start_link(opts) do
      {:ok, %{session: session}}
    end
  end

  @impl GPUI.Backend
  def open_window(%{session: session}, window_payload),
    do: Session.open_window(session, window_payload)

  @impl GPUI.Backend
  def update_window(%{session: session}, window_id, tree),
    do: Session.update_window(session, window_id, tree)

  @impl GPUI.Backend
  def put_resource(%{session: session}, resource_id, resource),
    do: Session.put_resource(session, resource_id, resource)

  @impl GPUI.Backend
  def drop_resource(%{session: session}, resource_id),
    do: Session.drop_resource(session, resource_id)

  @impl GPUI.Backend
  def drain_events(%{session: session}), do: Session.drain_events(session)

  @impl GPUI.Backend
  def emit_test_event(%{session: session}, event), do: Session.emit_test_event(session, event)

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled
end
