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

  defmodule PlainView do
    use GPUI.View

    @impl GPUI.View
    def render(_assigns), do: %GPUI.Element{type: :div}
  end

  defmodule PlainApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Plain" do
           root(PlainView)
         end
       ]}
    end
  end

  defmodule DuplicateKeyApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "duplicate", "First" do
           root(PlainView)
         end,
         window "duplicate", "Second" do
           root(PlainView)
         end
       ]}
    end
  end

  defmodule TooManyWindowsApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      windows =
        Enum.map(1..33, fn index ->
          %GPUI.WindowSpec{
            key: "window-#{index}",
            title: "Window #{index}",
            root: {PlainView, %{}}
          }
        end)

      {:ok, windows}
    end
  end

  defmodule CloseConfirmationView do
    use GPUI.View

    alias GPUI.UI
    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div>
        <text>Workspace</text>
        <Overlay.dialog
          id="close-confirmation"
          open={assigns.close_dialog_open}
          title="Close workspace?"
          phx-change="close_dialog_changed"
        >
          <:content>
            <div class="flex flex-col gap-3">
              <text>Unsaved changes will be discarded.</text>
              <div class="flex gap-2">
                <UI.button id="cancel-close" label="Cancel" phx-click="cancel_close" />
                <UI.button id="confirm-close" label="Close" phx-click="confirm_close" />
              </div>
            </div>
          </:content>
        </Overlay.dialog>
      </div>
      """
    end

    @impl GPUI.View
    def handle_window_event(:close_request, _event, assigns),
      do: {:noreply, %{assigns | close_dialog_open: true}}

    def handle_window_event(_event, _payload, assigns), do: {:noreply, assigns}

    @impl GPUI.View
    def handle_event("close_dialog_changed", %{value: false}, assigns),
      do: {:noreply, %{assigns | close_dialog_open: false}}

    def handle_event("cancel_close", _event, assigns),
      do: {:noreply, %{assigns | close_dialog_open: false}}

    def handle_event("confirm_close", _event, assigns), do: {:close, assigns}
  end

  defmodule CloseConfirmationApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Close confirmation" do
           root(CloseConfirmationView, close_dialog_open: false)
         end
       ]}
    end
  end

  defmodule InvalidLifecycleView do
    use GPUI.View

    @impl GPUI.View
    def render(_assigns), do: %GPUI.Element{type: :div}

    @impl GPUI.View
    def handle_window_event(:focus, _event, assigns), do: {:close, assigns}
    def handle_window_event(_event, _payload, assigns), do: {:noreply, assigns}
  end

  defmodule InvalidLifecycleApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Invalid lifecycle" do
           root(InvalidLifecycleView)
         end
       ]}
    end
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
           chrome(:content)
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
    assert window.chrome == :content

    payload = Session.window_payload(window)
    assert payload.lifecycle == [:close_request, :focus, :blur]

    assert %{
             min_size: [320, 240],
             resizable: false,
             chrome: :content,
             commands: [
               {"refresh", "primary-r"},
               {"focus_filter", "primary-shift-f"}
             ]
           } = Session.window_payload(window)
  end

  test "views without a lifecycle callback retain ordinary platform lifecycle" do
    assert {:ok, [window]} = PlainApp.mount(%{})
    window = %{WindowSpec.validate!(window) | id: 1}

    assert Session.window_payload(window).lifecycle == []
  end

  test "keyed window DSL rejects duplicate initial topology" do
    previous = Process.flag(:trap_exit, true)

    assert {:error, {:duplicate_window_key, "duplicate"}} =
             Session.start_link(app: DuplicateKeyApp)

    Process.flag(:trap_exit, previous)
  end

  test "bounds the number of windows in one session" do
    previous = Process.flag(:trap_exit, true)

    assert {:error, {:too_many_windows, 32}} = Session.start_link(app: TooManyWindowsApp)

    Process.flag(:trap_exit, previous)
  end

  test "routes fixed lifecycle atoms through the optional view callback" do
    {:ok, session} = Session.start_link(app: App)

    {focus, snapshot} =
      Session.dispatch_event(session, %{type: :window_focus, window_id: 1})

    assert focus.type == :window_focus
    refute Map.has_key?(focus, :event)
    assert [%{id: 1}] = snapshot.windows

    {close, snapshot} =
      Session.dispatch_event(session, %{type: :window_close_request, window_id: 1})

    assert close.type == :window_close_request
    refute Map.has_key?(close, :event)
    assert snapshot.windows == []

    {closed, snapshot} =
      Session.dispatch_event(session, %{type: :window_closed, window_id: 1})

    assert closed.type == :window_closed
    assert snapshot.windows == []
  end

  test "a declarative confirmation can cancel or approve window closure" do
    {:ok, session} = Session.start_link(app: CloseConfirmationApp)

    {_event, snapshot} =
      Session.dispatch_event(session, %{type: :window_close_request, window_id: 1})

    assert [window] = snapshot.windows
    assert window.root.assigns.close_dialog_open
    assert component(window.root.tree, :ui_dialog).attrs.open

    {_event, snapshot} =
      Session.dispatch_event(session, %{
        type: :click,
        window_id: 1,
        event: "cancel_close"
      })

    assert [window] = snapshot.windows
    refute window.root.assigns.close_dialog_open
    refute component(window.root.tree, :ui_dialog).attrs.open

    Session.dispatch_event(session, %{type: :window_close_request, window_id: 1})

    {_event, snapshot} =
      Session.dispatch_event(session, %{
        type: :click,
        window_id: 1,
        event: "confirm_close"
      })

    assert snapshot.windows == []
  end

  test "close approval is only valid for close requests" do
    Process.flag(:trap_exit, true)
    {:ok, session} = Session.start_link(app: InvalidLifecycleApp)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        assert catch_exit(Session.dispatch_event(session, %{type: :window_focus, window_id: 1}))
      end)

    assert log =~ "expected {:noreply, assigns}"
  end

  test "rejects malformed window lifecycle contracts" do
    assert_raise ArgumentError, ~r/minimum size/, fn ->
      WindowSpec.validate!(%WindowSpec{title: "Invalid", min_size: {0, 240}})
    end

    assert_raise ArgumentError, ~r/resizable must be a boolean/, fn ->
      window = struct!(WindowSpec, title: "Invalid", resizable: :yes)
      WindowSpec.validate!(window)
    end

    assert_raise ArgumentError, ~r/window chrome must be :system or :content/, fn ->
      window = struct!(WindowSpec, title: "Invalid", chrome: :frameless)
      WindowSpec.validate!(window)
    end

    assert_raise ArgumentError, ~r/window key must contain 1 through 128 bytes/, fn ->
      WindowSpec.validate!(%WindowSpec{key: String.duplicate("k", 129), title: "Invalid"})
    end

    assert_raise ArgumentError, ~r/window title must be at most 512 bytes/, fn ->
      WindowSpec.validate!(%WindowSpec{title: String.duplicate("t", 513)})
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

  defp component(%{type: type} = element, type), do: element

  defp component(%{children: children}, type) do
    Enum.find_value(children, &component(&1, type))
  end

  defp component(_child, _type), do: nil
end
