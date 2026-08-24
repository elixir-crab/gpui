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

  defmodule ExtensionView do
    use GPUI.View

    @impl GPUI.View
    def render(_assigns) do
      GPUI.UI.frost(%{id: "versioned-frost", children: ["content"]})
    end
  end

  test "generated extension payloads render through exact native version checks", %{ui: ui} do
    assert ^ui = render(ui, ExtensionView, %{})
  end

  test "native rejects explicit mismatched extension payload versions", %{ui: ui} do
    tree =
      ExtensionView
      |> GPUI.Test.render(%{})
      |> GPUI.Element.to_payload()
      |> put_in([:attrs, :__extension_version__], 2)

    viewport = %{type: :viewport, attrs: %{}, children: [tree]}

    assert_raise ArgumentError, fn ->
      GPUI.Native.Test.render(ui.pid |> :sys.get_state() |> Map.fetch!(:session), viewport)
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

  defp start_ui(owner \\ self()) do
    child_spec =
      Supervisor.child_spec(
        {GPUI.Test.Native, owner: owner, size: {240, 120}},
        id: {GPUI.Test.Native, make_ref()},
        restart: :temporary
      )

    pid = start_supervised!(child_spec)
    GPUI.Test.Native.ui(pid)
  end

  test "simultaneous sessions isolate events and lifecycle", %{ui: ui} do
    other = start_ui()
    refute other == ui

    render(ui, ControlsView, %{})
    render(other, ControlsView, %{})
    focus(ui, "enabled-switch")
    press(ui, :space)

    assert_receive {:gpui, ^ui, {:event, %{event: "changed", value: true}}}
    refute_receive {:gpui, ^other, {:event, _event}}

    GPUI.Test.Native.stop(ui)
    refute Process.alive?(ui.pid)

    focus(other, "enabled-switch")
    press(other, :space)
    assert_receive {:gpui, ^other, {:event, %{event: "changed", value: true}}}
  end

  test "stale handles raise a native test session error", %{ui: ui} do
    GPUI.Test.Native.stop(ui)
    assert :ok = GPUI.Test.Native.stop(ui)

    error = assert_raise GPUI.Test.Error, fn -> focus(ui, "enabled-switch") end
    assert error.operation == :session
    assert error.reason == :session_stopped
    assert error.ui == ui
  end

  test "an owner exit terminates its temporary UI session" do
    parent = self()

    owner =
      spawn(fn ->
        {:ok, pid} = GPUI.Test.Native.start_link(owner: self(), size: {240, 120})
        send(parent, {:owned_ui, GPUI.Test.Native.ui(pid)})
        receive do: (:stop -> :ok)
      end)

    assert_receive {:owned_ui, ui}
    monitor = Process.monitor(ui.pid)
    send(owner, :stop)
    assert_receive {:DOWN, ^monitor, :process, _pid, :normal}
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
