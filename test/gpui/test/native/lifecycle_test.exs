defmodule GPUI.Test.Native.LifecycleTest do
  use GPUI.Test, native: [size: {240, 120}]

  defmodule ControlsView do
    use GPUI.View

    @impl GPUI.View
    def render(_assigns) do
      ~GPUI"""
      <GPUI.UI.switch
        id="enabled-switch"
        label="Enabled"
        checked={false}
        phx-change="changed"
      />
      """
    end
  end

  test "native command failures expose operation, subject, reason, and UI", %{ui: ui} do
    render(ui, ControlsView, %{})

    error =
      assert_raise GPUI.Test.Error, ~r/focus.*missing.*unknown_focus_target/, fn ->
        focus(ui, "missing")
      end

    assert error.operation == :focus
    assert error.subject == "missing"
    assert error.reason == "unknown_focus_target"
    assert error.ui == ui
  end

  test "invalid public arguments are rejected without killing the session", %{ui: ui} do
    render(ui, ControlsView, %{})

    invalid_calls = [
      fn -> focus(ui, "") end,
      fn -> bounds(ui, String.duplicate("x", 1_025)) end,
      fn -> click(ui, {1_000_001, 0}) end,
      fn -> scroll(ui, "enabled-switch", delta: {0, 100_001}) end,
      fn -> scroll(ui, "enabled-switch", delta: {0, 1}, extra: true) end,
      fn -> resize(ui, {0, 100}) end,
      fn -> advance(ui, -1) end,
      fn -> advance(ui, 86_400_001) end,
      fn -> press(ui, :unsupported) end,
      fn -> press(ui, "") end,
      fn -> type(ui, String.duplicate("x", 1_048_577)) end
    ]

    Enum.each(invalid_calls, fn call -> assert_raise ArgumentError, call end)

    focus(ui, "enabled-switch")
    press(ui, :space)
    assert_receive {:gpui, ^ui, {:event, %{event: "changed", value: true}}}
  end

  test "a failed command does not break the session or a later session", %{ui: ui} do
    render(ui, ControlsView, %{})

    assert_raise GPUI.Test.Error, fn -> bounds(ui, "missing") end

    focus(ui, "enabled-switch")
    press(ui, :space)

    assert_receive {:gpui, ^ui, {:event, %{event: "changed", value: true}}}
  end
end
