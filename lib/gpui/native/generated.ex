defmodule GPUI.Native.Generated do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      def start_runtime do
        :erlang.nif_error(:nif_not_loaded)
      end

      def open_window(_runtime, _window) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def update_window(_runtime, _window_id, _tree) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def close_window(_runtime, _window_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def await_frame(_runtime, _window_id, _timeout_ms) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def stop_runtime(_runtime) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def set_theme(_runtime, _mode) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def put_resource(_runtime, _resource_id, _resource) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def drop_resource(_runtime, _resource_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def drain_events(_runtime) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def inject_event(_runtime, _event) do
        :erlang.nif_error(:nif_not_loaded)
      end
    end
  end
end
