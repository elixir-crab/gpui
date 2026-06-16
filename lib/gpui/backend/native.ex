defmodule GPUI.Backend.Native do
  @moduledoc false

  @behaviour GPUI.Backend

  @impl GPUI.Backend
  def init(_opts) do
    with {:ok, runtime} <- GPUI.Native.start_runtime() do
      {:ok, %{runtime: runtime}}
    end
  end

  @impl GPUI.Backend
  def open_window(%{runtime: runtime}, window_payload) do
    case GPUI.Native.open_window(runtime, window_payload) do
      {:ok, _title} -> :ok
      error -> error
    end
  end

  @impl GPUI.Backend
  def update_window(%{runtime: runtime}, window_id, tree) do
    case GPUI.Native.update_window(runtime, window_id, tree) do
      {:ok, _window_id} -> :ok
      error -> error
    end
  end

  @impl GPUI.Backend
  def put_resource(%{runtime: runtime}, resource_id, resource) do
    case GPUI.Native.put_resource(runtime, to_string(resource_id), resource) do
      {:ok, _resource_id} -> :ok
      error -> error
    end
  end

  @impl GPUI.Backend
  def drop_resource(%{runtime: runtime}, resource_id) do
    case GPUI.Native.drop_resource(runtime, to_string(resource_id)) do
      {:ok, _resource_id} -> :ok
      error -> error
    end
  end

  @impl GPUI.Backend
  def drain_events(%{runtime: runtime}), do: GPUI.Native.drain_events(runtime)

  @impl GPUI.Backend
  def inject_event(%{runtime: runtime}, event), do: GPUI.Native.inject_event(runtime, event)

  @impl GPUI.Backend
  def handle_info(_state, _message), do: :unhandled
end
