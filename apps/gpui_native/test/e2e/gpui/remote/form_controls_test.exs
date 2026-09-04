defmodule GPUI.Remote.FormControlsE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

  alias GPUITest.Desktop

  @moduletag :e2e

  defmodule FormView do
    use GPUI.View

    alias GPUI.UI
    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[360px] h-[340px] p-4 gap-4 bg-slate-900">
        <GPUI.UI.switch
          id="remote-switch"
          label="Notifications"
          checked={assigns.notifications}
          phx-change="notifications_changed"
        />
        <GPUI.UI.radio_group
          id="remote-radio"
          label="Plan"
          value={assigns.plan}
          options={[{"Free", "free"}, {"Team", "team"}]}
          orientation="horizontal"
          phx-change="plan_changed"
        />
        <Overlay.popover
          id="remote-popover"
          label="Account"
          open={assigns.overlay_open}
          phx-change="overlay_changed"
        >
          <:trigger>
            <UI.button id="remote-popover-trigger" label="Account" />
          </:trigger>
          <:content><text>Remote account</text></:content>
        </Overlay.popover>
        <Overlay.dialog
          id="remote-dialog"
          open={assigns.dialog_open}
          title="Remote dialog"
          width={280}
          phx-change="dialog_changed"
        >
          <:trigger><UI.button id="remote-dialog-trigger" label="Settings" /></:trigger>
          <:content><UI.button id="remote-dialog-action" label="Dialog action" /></:content>
        </Overlay.dialog>
        <Overlay.dropdown_menu
          id="remote-menu"
          label="File menu"
          open={assigns.menu_open}
          phx-change="menu_open_changed"
          phx-select="menu_selected"
        >
          <:trigger><UI.button id="remote-menu-trigger" label="File" /></:trigger>
          <:item value="open">Open file</:item>
          <:item value="disabled" disabled={true}>Disabled item</:item>
        </Overlay.dropdown_menu>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("notifications_changed", %{value: notifications}, assigns),
      do: {:noreply, %{assigns | notifications: notifications}}

    def handle_event("plan_changed", %{value: plan}, assigns),
      do: {:noreply, %{assigns | plan: plan}}

    def handle_event("overlay_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | overlay_open: open}}

    def handle_event("dialog_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | dialog_open: open}}

    def handle_event("menu_open_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | menu_open: open}}

    def handle_event("menu_selected", %{value: value}, assigns),
      do: {:noreply, %{assigns | menu_open: false, menu_selection: value}}
  end

  defmodule FormApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Remote Form E2E" do
           size(360, 340)

           root(FormView,
             notifications: false,
             plan: "free",
             overlay_open: false,
             dialog_open: false,
             menu_open: false,
             menu_selection: nil
           )
         end
       ]}
    end
  end

  test "desktop renders the remote form boundary", %{desktop: desktop} do
    port = available_port()

    _server =
      start_supervised!(
        Supervisor.child_spec({GPUI.Remote.Server, app: FormApp, port: port}, id: make_ref())
      )

    client =
      start_supervised!(
        Supervisor.child_spec(
          {GPUI.Remote.Client,
           host: "127.0.0.1", port: port, display: GPUI.Display.Native, poll_interval: 10},
          id: make_ref()
        )
      )

    Desktop.attach(desktop, client)

    assert {:ok, %{windows: [_window]}} = GPUI.Remote.Client.mount(client)
    window_id = Desktop.window!(desktop, "GPUI Remote Form E2E")
    Desktop.await_frame!(desktop, client, 1, window_id)

    assert Process.alive?(client)
  end

  defp available_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, {_address, port}} = :inet.sockname(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
