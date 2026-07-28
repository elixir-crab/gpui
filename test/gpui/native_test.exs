defmodule GPUI.NativeTest do
  use ExUnit.Case, async: true

  test "generated lifecycle boundary starts and stops a native runtime" do
    assert GPUI.Native.compiled?()
    assert {:ok, runtime} = GPUI.Native.start_runtime()
    assert {:ok, :ok} = GPUI.Native.stop_runtime(runtime)
  end

  test "native events cross the boundary as structured maps" do
    assert {:ok, runtime} = GPUI.Native.start_runtime()

    assert {:ok, :ok} =
             GPUI.Native.inject_event(runtime, %{type: :click, window_id: 7, event: "save"})

    assert {:ok, [%{type: :click, window_id: 7, event: "save"}]} =
             GPUI.Native.drain_events(runtime)

    assert {:ok, :ok} =
             GPUI.Native.inject_event(runtime, %{type: :command, window_id: 7, event: "save"})

    assert {:ok, [%{type: :command, window_id: 7, event: "save"}]} =
             GPUI.Native.drain_events(runtime)

    assert {:ok, :ok} =
             GPUI.Native.inject_event(runtime, %{type: :window_closed, window_id: 7})

    assert {:ok, [%{type: :window_closed, window_id: 7}]} = GPUI.Native.drain_events(runtime)

    assert {:ok, :ok} =
             GPUI.Native.inject_event(runtime, %{
               type: :change,
               window_id: 7,
               event: "language_changed",
               value: nil
             })

    assert {:ok, [%{type: :change, window_id: 7, event: "language_changed", value: nil}]} =
             GPUI.Native.drain_events(runtime)
  end

  test "rejects unsupported native component themes" do
    Process.flag(:trap_exit, true)

    assert {:error, {:invalid_theme, :system}} =
             GPUI.Display.Native.start_link(theme: :system)
  end

  test "exposes the complete generated native lifecycle boundary" do
    Code.ensure_loaded!(GPUI.Native)

    assert function_exported?(GPUI.Native, :decode_image, 1)
    assert function_exported?(GPUI.Native, :text_buffer_new, 3)
    assert function_exported?(GPUI.Native, :text_buffer_snapshot, 1)
    assert function_exported?(GPUI.Native, :text_buffer_transact, 2)
    assert function_exported?(GPUI.Native, :text_buffer_undo, 2)
    assert function_exported?(GPUI.Native, :text_buffer_redo, 2)
    assert function_exported?(GPUI.Native, :open_window, 2)
    assert function_exported?(GPUI.Native, :update_window, 3)
    assert function_exported?(GPUI.Native, :close_window, 2)
    assert function_exported?(GPUI.Native, :await_frame, 3)
    assert function_exported?(GPUI.Native, :frame_token, 2)
    assert function_exported?(GPUI.Native, :await_frame_after, 4)
    assert function_exported?(GPUI.Native, :stop_runtime, 1)
    assert function_exported?(GPUI.Native, :set_theme, 2)
  end
end
