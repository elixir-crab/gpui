defmodule GPUI.CommandTest do
  use ExUnit.Case, async: true

  alias GPUI.Command
  alias GPUI.Session
  alias GPUI.WindowSpec

  defmodule View do
    use GPUI.View

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

    assert %{
             commands: [
               {"refresh", "primary-r"},
               {"focus_filter", "primary-shift-f"}
             ]
           } = Session.window_payload(window)
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
