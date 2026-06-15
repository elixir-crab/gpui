defmodule GPUI.Backend.Host do
  @moduledoc false

  @behaviour GPUI.Backend

  @impl GPUI.Backend
  def init(opts), do: {:ok, %{port: GPUI.Host.start_link(opts)}}

  @impl GPUI.Backend
  def open_window(%{port: port}, window_payload) do
    GPUI.Host.command(port, GPUI.Protocol.command(:open_window, window_payload))
    :ok
  end

  @impl GPUI.Backend
  def update_window(%{port: port}, window_id, tree) do
    GPUI.Host.command(
      port,
      GPUI.Protocol.command(:update_view, %{view_id: window_id, tree: tree})
    )

    :ok
  end

  @impl GPUI.Backend
  def drain_events(_state), do: {:ok, []}

  @impl GPUI.Backend
  def emit_test_event(_state, _event), do: {:error, :unsupported}

  @impl GPUI.Backend
  def handle_info(%{port: port}, {port, {:data, payload}}) do
    {:ok, GPUI.Protocol.decode(payload)}
  end

  def handle_info(%{port: port}, {port, {:exit_status, status}}) do
    {:ok, %{op: :host_exit, status: status}}
  end

  def handle_info(_state, _message), do: :unhandled
end
