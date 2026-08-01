defmodule GPUI.CommandTest do
  use ExUnit.Case, async: true

  alias GPUI.Command
  alias GPUI.Session
  alias GPUI.WindowSpec

  defmodule View do
    use GPUI.View

    @impl GPUI.View
    def handle_window_event(:close_request, _event, assigns), do: {:close, assigns}
    def handle_window_event(_event, _payload, assigns), do: {:noreply, assigns}

    @impl GPUI.View
    def render(_assigns), do: %GPUI.Element{type: :div}
  end

  defmodule App do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Commands" do
           size(480, 320)
           min_size(320, 240)
           resizable(false)
           shortcut("refresh", "primary-r")
           shortcut("focus_filter", "primary-shift-f")
           root(View)
         end
       ]}
    end
  end

  test "window DSL keeps bounded commands in renderer-independent snapshots" do
    assert {:ok, [window]} = App.mount(%{})
    window = %{WindowSpec.validate!(window) | id: 1}

    assert [
             %Command{id: "refresh", shortcut: "primary-r"},
             %Command{id: "focus_filter", shortcut: "primary-shift-f"}
           ] = window.commands

    assert window.min_size == {320, 240}
    refute window.resizable

    payload = Session.window_payload(window)
    assert payload.lifecycle == [:close_request, :focus, :blur]

    assert %{
             min_size: [320, 240],
             resizable: false,
             commands: [
               {"refresh", "primary-r"},
               {"focus_filter", "primary-shift-f"}
             ]
           } = Session.window_payload(window)
  end

  test "routes fixed lifecycle atoms through the optional view callback" do
    {:ok, session} = Session.start_link(app: App)

    {focus, snapshot} =
      Session.dispatch_event(session, %{type: :window_focus, window_id: 1})

    assert focus.type == :window_focus
    assert [%{id: 1}] = snapshot.windows

    {close, snapshot} =
      Session.dispatch_event(session, %{type: :window_close_request, window_id: 1})

    assert close.type == :window_close_request
    assert snapshot.windows == []
  end

  test "rejects malformed window lifecycle contracts" do
    assert_raise ArgumentError, ~r/minimum size/, fn ->
      WindowSpec.validate!(%WindowSpec{title: "Invalid", min_size: {0, 240}})
    end

    assert_raise ArgumentError, ~r/resizable must be a boolean/, fn ->
      window = struct!(WindowSpec, title: "Invalid", resizable: :yes)
      WindowSpec.validate!(window)
    end
  end

  test "rejects malformed and duplicate command contracts" do
    assert_raise ArgumentError, ~r/primary, ctrl, or alt/, fn ->
      Command.new("refresh", "shift-r")
    end

    assert_raise ArgumentError, ~r/lowercase key/, fn ->
      Command.new("refresh", "primary-R")
    end

    assert_raise ArgumentError, ~r/command ids must be unique/, fn ->
      WindowSpec.validate!(%WindowSpec{
        title: "Duplicate IDs",
        root: {View, %{}},
        commands: [Command.new("refresh", "primary-r"), Command.new("refresh", "primary-u")]
      })
    end

    assert_raise ArgumentError, ~r/command shortcuts must be unique/, fn ->
      WindowSpec.validate!(%WindowSpec{
        title: "Duplicate shortcuts",
        root: {View, %{}},
        commands: [Command.new("refresh", "primary-r"), Command.new("reload", "primary-r")]
      })
    end
  end
end
