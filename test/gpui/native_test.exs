defmodule GPUI.NativeTest do
  use ExUnit.Case, async: true

  test "generated lifecycle boundary starts and stops a native runtime" do
    assert {:ok, runtime} = GPUI.Native.start_runtime()
    assert {:ok, :ok} = GPUI.Native.stop_runtime(runtime)
  end

  test "exposes the complete generated native lifecycle boundary" do
    Code.ensure_loaded!(GPUI.Native)

    assert function_exported?(GPUI.Native, :open_window, 2)
    assert function_exported?(GPUI.Native, :update_window, 3)
    assert function_exported?(GPUI.Native, :close_window, 2)
    assert function_exported?(GPUI.Native, :stop_runtime, 1)
  end
end
