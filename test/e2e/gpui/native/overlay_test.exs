defmodule GPUI.Native.OverlayE2ETest do
  use GPUI.Test, desktop: true

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

  test "dialog contains keyboard focus and restores its trigger after every close path", %{
    desktop: desktop
  } do
    title = "GPUI Overlay E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: OverlayApp, args: %{title: title})
    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{open: false, dialog_open: false, menu_open: false} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  test "dialog Escape requires both keyboard and closable policy", %{desktop: desktop} do
    title = "GPUI Overlay E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: OverlayApp, args: %{title: title})
    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{open: false, dialog_open: false, menu_open: false} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  test "controlled overlays dismiss and dropdown items select", %{desktop: desktop} do
    title = "GPUI Overlay E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: OverlayApp, args: %{title: title})
    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{open: false, dialog_open: false, menu_open: false} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
