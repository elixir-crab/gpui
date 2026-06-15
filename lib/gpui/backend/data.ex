defmodule GPUI.Backend.Data do
  @moduledoc false

  @behaviour GPUI.Backend

  @impl GPUI.Backend
  def init(_opts), do: {:ok, %{}}

  @impl GPUI.Backend
  def open_window(_state, _window_payload), do: :ok

  @impl GPUI.Backend
  def update_window(_state, _window_id, _tree), do: :ok

  @impl GPUI.Backend
  def put_resource(_state, _resource_id, _resource), do: :ok

  @impl GPUI.Backend
  def drop_resource(_state, _resource_id), do: :ok

  @impl GPUI.Backend
  def drain_events(_state), do: {:ok, []}

  @impl GPUI.Backend
  def emit_test_event(_state, _event), do: {:error, :unsupported}

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled
end
