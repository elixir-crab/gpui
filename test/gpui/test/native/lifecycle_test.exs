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

  test "a failed command does not break the session or a later session", %{ui: ui} do
    render(ui, ControlsView, %{})

    assert_raise GPUI.Test.Error, fn -> bounds(ui, "missing") end

    focus(ui, "enabled-switch")
    press(ui, :space)

    assert_receive {:gpui, ^ui, {:event, %{event: "changed", value: true}}}
  end
end
