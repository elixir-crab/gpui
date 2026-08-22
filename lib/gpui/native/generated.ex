defmodule GPUI.Native.Generated do
  @moduledoc "Generated Rustler NIF declarations used by GPUI.Native."
  defmacro __using__(_opts) do
    quote do
      def start_runtime do
        :erlang.nif_error(:nif_not_loaded)
      end

      def text_buffer_new(_text, _revision, _selections) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def text_buffer_snapshot(_buffer) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def text_buffer_transact(_buffer, _transaction) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def text_buffer_undo(_buffer, _base_revision) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def text_buffer_redo(_buffer, _base_revision) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def open_window(_runtime, _window) do
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

      def native_test_start(_width, _height) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_render(_test_id, _tree) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_focus(_test_id, _component_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_click(_test_id, _element_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_click_at(_test_id, _x, _y) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_scroll(_test_id, _element_id, _delta_x, _delta_y) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_input(_test_id, _text) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_resize(_test_id, _width, _height) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_bounds(_test_id, _element_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_idle(_test_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_advance(_test_id, _milliseconds) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_key(_test_id, _key) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_events(_test_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def native_test_stop(_test_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def decode_image(_bytes) do
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

      def frame_token(_runtime, _window_id) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def await_frame_after(_runtime, _window_id, _generation, _timeout_ms) do
        :erlang.nif_error(:nif_not_loaded)
      end
    end
  end
end
