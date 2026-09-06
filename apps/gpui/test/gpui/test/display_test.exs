defmodule GPUI.Test.DisplayTest do
  use ExUnit.Case, async: true

  test "advertises no renderer enhancements" do
    display = start_supervised!({GPUI.Test.Display, []})
    assert {:ok, []} = GPUI.Display.Support.presentation_capabilities(GPUI.Test.Display, display)
  end

  test "records synchronized snapshots chronologically" do
    display = start_supervised!({GPUI.Test.Display, []})
    first = %GPUI.Snapshot{windows: [], resources: %{}}
    second = %GPUI.Snapshot{windows: [%{id: 1}], resources: %{}}

    assert :ok = GPUI.Test.Display.sync(display, first)
    assert :ok = GPUI.Test.Display.sync(display, second)
    assert [^first, ^second] = GPUI.Test.Display.snapshots(display)
    assert ^second = GPUI.Test.Display.latest_snapshot(display)
  end
end
