defmodule GPUI.Native.Facade do
  @moduledoc "Generated native boundary delegates used by GPUI.Native."
  defmacro __using__(_opts) do
    quote do
      def decode_image(_bytes) do
        apply(GPUI.Native.backend(), :decode_image, [_bytes])
      end

      def text_buffer_new(_text, _revision, _selections) do
        apply(GPUI.Native.backend(), :text_buffer_new, [_text, _revision, _selections])
      end

      def text_buffer_snapshot(_buffer) do
        apply(GPUI.Native.backend(), :text_buffer_snapshot, [_buffer])
      end

      def text_buffer_transact(_buffer, _transaction) do
        apply(GPUI.Native.backend(), :text_buffer_transact, [_buffer, _transaction])
      end

      def text_buffer_undo(_buffer, _base_revision) do
        apply(GPUI.Native.backend(), :text_buffer_undo, [_buffer, _base_revision])
      end

      def text_buffer_redo(_buffer, _base_revision) do
        apply(GPUI.Native.backend(), :text_buffer_redo, [_buffer, _base_revision])
      end

      def host_info() do
        apply(GPUI.Native.backend(), :host_info, [])
      end

      def start_runtime() do
        apply(GPUI.Native.backend(), :start_runtime, [])
      end

      def stop_runtime(_runtime) do
        apply(GPUI.Native.backend(), :stop_runtime, [_runtime])
      end

      def open_window(_runtime, _window) do
        apply(GPUI.Native.backend(), :open_window, [_runtime, _window])
      end

      def update_window(_runtime, _window_id, _tree) do
        apply(GPUI.Native.backend(), :update_window, [_runtime, _window_id, _tree])
      end

      def close_window(_runtime, _window_id) do
        apply(GPUI.Native.backend(), :close_window, [_runtime, _window_id])
      end

      def await_frame(_runtime, _window_id, _timeout_ms) do
        apply(GPUI.Native.backend(), :await_frame, [_runtime, _window_id, _timeout_ms])
      end

      def frame_token(_runtime, _window_id) do
        apply(GPUI.Native.backend(), :frame_token, [_runtime, _window_id])
      end

      def await_frame_after(_runtime, _window_id, _generation, _timeout_ms) do
        apply(GPUI.Native.backend(), :await_frame_after, [
          _runtime,
          _window_id,
          _generation,
          _timeout_ms
        ])
      end

      def set_theme(_runtime, _mode) do
        apply(GPUI.Native.backend(), :set_theme, [_runtime, _mode])
      end

      def put_resource(_runtime, _resource_id, _resource) do
        apply(GPUI.Native.backend(), :put_resource, [_runtime, _resource_id, _resource])
      end

      def drop_resource(_runtime, _resource_id) do
        apply(GPUI.Native.backend(), :drop_resource, [_runtime, _resource_id])
      end

      def drain_events(_runtime) do
        apply(GPUI.Native.backend(), :drain_events, [_runtime])
      end

      def inject_event(_runtime, _event) do
        apply(GPUI.Native.backend(), :inject_event, [_runtime, _event])
      end

      def native_test_start(_width, _height) do
        apply(GPUI.Native.backend(), :native_test_start, [_width, _height])
      end

      def native_test_render(_session, _tree) do
        apply(GPUI.Native.backend(), :native_test_render, [_session, _tree])
      end

      def native_test_resize(_session, _width, _height) do
        apply(GPUI.Native.backend(), :native_test_resize, [_session, _width, _height])
      end

      def native_test_bounds(_session, _target) do
        apply(GPUI.Native.backend(), :native_test_bounds, [_session, _target])
      end

      def native_test_focus(_session, _target) do
        apply(GPUI.Native.backend(), :native_test_focus, [_session, _target])
      end

      def native_test_click(_session, _target) do
        apply(GPUI.Native.backend(), :native_test_click, [_session, _target])
      end

      def native_test_click_at(_session, _x, _y) do
        apply(GPUI.Native.backend(), :native_test_click_at, [_session, _x, _y])
      end

      def native_test_scroll(_session, _target, _delta_x, _delta_y) do
        apply(GPUI.Native.backend(), :native_test_scroll, [_session, _target, _delta_x, _delta_y])
      end

      def native_test_input(_session, _text) do
        apply(GPUI.Native.backend(), :native_test_input, [_session, _text])
      end

      def native_test_key(_session, _key) do
        apply(GPUI.Native.backend(), :native_test_key, [_session, _key])
      end

      def native_test_advance(_session, _milliseconds) do
        apply(GPUI.Native.backend(), :native_test_advance, [_session, _milliseconds])
      end

      def native_test_idle(_session) do
        apply(GPUI.Native.backend(), :native_test_idle, [_session])
      end

      def native_test_events(_session) do
        apply(GPUI.Native.backend(), :native_test_events, [_session])
      end

      def native_test_stop(_session) do
        apply(GPUI.Native.backend(), :native_test_stop, [_session])
      end
    end
  end
end
