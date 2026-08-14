defmodule GPUI.Native.OverlayE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule OverlayView do
    use GPUI.View

    alias GPUI.UI
    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[420px] h-[300px] p-4 gap-4 bg-slate-900">
        <Overlay.popover
          id="account-popover"
          label="Account"
          open={assigns.open}
          phx-change="open_changed"
        >
          <:trigger>
            <UI.button id="account-trigger" label="Account" />
          </:trigger>
          <:content>
            <div class="w-[180px] p-2">
              <text>Account settings</text>
            </div>
          </:content>
        </Overlay.popover>
        <Overlay.tooltip id="account-help" delay={100}>
          <:trigger>
            <UI.button id="help-trigger" label="Help" phx-click="tooltip_clicked" />
          </:trigger>
          <:content>Open account help</:content>
        </Overlay.tooltip>
        <Overlay.dialog
          id="settings-dialog"
          open={assigns.dialog_open}
          title="Settings"
          width={300}
          phx-change="dialog_changed"
        >
          <:trigger><UI.button id="dialog-trigger" label="Settings" /></:trigger>
          <:content><UI.button id="dialog-action" label="Dialog action" /></:content>
        </Overlay.dialog>
        <Overlay.dropdown_menu
          id="file-menu"
          label="File menu"
          open={assigns.menu_open}
          phx-change="menu_open_changed"
          phx-select="menu_selected"
        >
          <:trigger><UI.button id="file-trigger" label="File" /></:trigger>
          <:item value="new">New file</:item>
          <:item value="disabled" disabled={true}>Disabled item</:item>
        </Overlay.dropdown_menu>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("open_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | open: open}}

    def handle_event("tooltip_clicked", _event, assigns),
      do: {:noreply, %{assigns | tooltip_clicked: true}}

    def handle_event("dialog_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | dialog_open: open}}

    def handle_event("menu_open_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | menu_open: open}}

    def handle_event("menu_selected", %{value: value}, assigns),
      do: {:noreply, %{assigns | menu_open: false, menu_selection: value}}
  end

  defmodule DialogFocusView do
    use GPUI.View

    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[420px] h-[300px] p-4 gap-4 bg-slate-900">
        <Overlay.dialog
          id="focus-dialog"
          open={assigns.open}
          title="Focus contract"
          width={300}
          keyboard={assigns.keyboard}
          closable={assigns.closable}
          close_button={assigns.close_button}
          phx-change="dialog_changed"
        >
          <:trigger>
            <button id="dialog-trigger"><text>Open dialog</text></button>
          </:trigger>
          <:content>
            <div
              id="first-action"
              accessibility_role="button"
              accessibility_label="First action"
              phx-click="first_action"
            >
              <text>First action</text>
            </div>
            <div
              id="second-action"
              accessibility_role="button"
              accessibility_label="Second action"
              phx-click="second_action"
            >
              <text>Second action</text>
            </div>
            <div
              id="controlled-close"
              accessibility_role="button"
              accessibility_label="Close dialog"
              phx-click="close_dialog"
            >
              <text>Close</text>
            </div>
          </:content>
        </Overlay.dialog>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("dialog_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | open: open}}

    def handle_event("close_dialog", _event, assigns),
      do: {:noreply, %{assigns | open: false}}

    def handle_event("first_action", _event, assigns),
      do: {:noreply, %{assigns | first_actions: assigns.first_actions + 1}}

    def handle_event("second_action", _event, assigns),
      do: {:noreply, %{assigns | second_actions: assigns.second_actions + 1}}
  end

  defmodule DialogFocusApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(args) do
      {:ok,
       [
         window args.title do
           size(420, 300)

           root(DialogFocusView,
             open: false,
             keyboard: args.keyboard,
             closable: args.closable,
             close_button: args.close_button,
             first_actions: 0,
             second_actions: 0
           )
         end
       ]}
    end
  end

  defmodule OverlayApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(420, 300)

           root(OverlayView,
             open: false,
             tooltip_clicked: false,
             dialog_open: false,
             menu_open: false,
             menu_selection: nil
           )
         end
       ]}
    end
  end

  test "dialog contains keyboard focus and restores its trigger after every close path" do
    {runtime, window_id} =
      start_dialog(keyboard: true, closable: true, close_button: false)

    Desktop.click!(window_id, 55, 28)
    Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)
    Desktop.await_frame!(runtime, 1, window_id)

    Desktop.key!(window_id, "Tab")
    Desktop.key!(window_id, "space")
    Desktop.eventually(fn -> assert %{first_actions: 1} = assigns(runtime) end)
    Desktop.key!(window_id, "Tab")
    Desktop.key!(window_id, "space")
    Desktop.eventually(fn -> assert %{second_actions: 1} = assigns(runtime) end)
    Desktop.key!(window_id, "Tab")
    Desktop.key!(window_id, "Tab")
    Desktop.key!(window_id, "space")
    Desktop.eventually(fn -> assert %{first_actions: 2} = assigns(runtime) end)

    Desktop.key!(window_id, "shift+Tab")
    Desktop.key!(window_id, "space")
    Desktop.eventually(fn -> assert %{open: false} = assigns(runtime) end)

    Desktop.key!(window_id, "space")
    Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)
    Desktop.await_frame!(runtime, 1, window_id)
    Desktop.key!(window_id, "Escape")
    Desktop.eventually(fn -> assert %{open: false} = assigns(runtime) end)
  end

  test "dialog Escape requires both keyboard and closable policy" do
    for policy <- [
          [keyboard: false, closable: true, close_button: false],
          [keyboard: true, closable: false, close_button: false]
        ] do
      {runtime, window_id} = start_dialog(policy)
      Desktop.click!(window_id, 55, 28)
      Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)
      Desktop.await_frame!(runtime, 1, window_id)

      Desktop.assert_no_runtime_update!(runtime, 1, window_id, fn ->
        Desktop.key!(window_id, "Escape")
      end)

      assert %{open: true} = assigns(runtime)

      assert {:ok, _reply} =
               GPUI.Runtime.inject_event(runtime, %{
                 type: :click,
                 window_id: 1,
                 event: "close_dialog",
                 value: nil
               })

      assert %{open: false} = assigns(runtime)
      assert :ok = GPUI.Runtime.await_frame(runtime, 1)

      Desktop.click!(window_id, 55, 28)
      Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)

      Desktop.stop_process(runtime)
    end
  end

  test "controlled overlays dismiss and dropdown items select" do
    title = "GPUI Overlay E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: OverlayApp, args: %{title: title})
    :ok = GPUI.Runtime.subscribe(runtime)
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)
    Desktop.click!(window_id, 50, 28)
    Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)

    Desktop.key!(window_id, "Escape")
    Desktop.eventually(fn -> assert %{open: false} = assigns(runtime) end)

    Desktop.key!(window_id, "space")
    Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)
    Desktop.key!(window_id, "Escape")
    Desktop.eventually(fn -> assert %{open: false} = assigns(runtime) end)

    Desktop.click!(window_id, 50, 28)
    Desktop.eventually(fn -> assert %{open: true} = assigns(runtime) end)

    Desktop.click!(window_id, 360, 190)
    Desktop.eventually(fn -> assert %{open: false} = assigns(runtime) end)

    assert {:ok, hover_generation} = GPUI.Runtime.frame_token(runtime, 1)
    Desktop.command!(["mousemove", "--sync", "--window", window_id, "50", "72"])
    Desktop.await_frame_after!(runtime, 1, hover_generation)
    assert {:ok, tooltip_generation} = GPUI.Runtime.frame_token(runtime, 1)
    Desktop.await_frame_after!(runtime, 1, tooltip_generation)
    assert Process.alive?(runtime)
    Desktop.command!(["mousemove", "--sync", "--window", window_id, "360", "190"])
    Desktop.click!(window_id, 50, 72)
    Desktop.eventually(fn -> assert %{tooltip_clicked: true} = assigns(runtime) end)

    Desktop.click!(window_id, 55, 116)
    Desktop.eventually(fn -> assert %{dialog_open: true} = assigns(runtime) end)
    Desktop.await_frame!(runtime, 1, window_id)
    Desktop.key!(window_id, "Escape")
    Desktop.eventually(fn -> assert %{dialog_open: false} = assigns(runtime) end)

    Desktop.key!(window_id, "space")
    Desktop.eventually(fn -> assert %{dialog_open: true} = assigns(runtime) end)
    Desktop.await_frame!(runtime, 1, window_id)
    Desktop.click!(window_id, 400, 270)
    Desktop.eventually(fn -> assert %{dialog_open: false} = assigns(runtime) end)

    Desktop.click!(window_id, 55, 160)
    Desktop.eventually(fn -> assert %{menu_open: true} = assigns(runtime) end)
    Desktop.await_frame!(runtime, 1, window_id)
    Desktop.click!(window_id, 70, 212)

    Desktop.eventually(fn ->
      assert %{menu_open: false, menu_selection: "new"} = assigns(runtime)
    end)
  end

  defp start_dialog(policy) do
    title = "GPUI Dialog Focus E2E #{System.unique_integer([:positive])}"
    args = policy |> Map.new() |> Map.put(:title, title)
    {:ok, runtime} = GPUI.Runtime.start_link(app: DialogFocusApp, args: args)
    :ok = GPUI.Runtime.subscribe(runtime)
    on_exit(fn -> Desktop.stop_process(runtime) end)
    {runtime, Desktop.window_id!(title)}
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
