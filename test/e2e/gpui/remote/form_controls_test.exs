defmodule GPUI.Remote.FormControlsE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e

  defmodule FormView do
    use GPUI.View

    alias GPUI.UI
    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[360px] h-[220px] p-4 gap-4 bg-slate-900">
        <GPUI.UI.switch
          id="remote-switch"
          label="Notifications"
          checked={assigns.notifications}
          phx-change="notifications_changed"
        />
        <GPUI.UI.radio_group
          id="remote-radio"
          value={assigns.plan}
          options={[{"Free", "free"}, {"Team", "team"}]}
          orientation="horizontal"
          phx-change="plan_changed"
        />
        <Overlay.popover
          id="remote-popover"
          open={assigns.overlay_open}
          phx-change="overlay_changed"
        >
          <:trigger>
            <UI.button id="remote-popover-trigger" label="Account" />
          </:trigger>
          <:content><text>Remote account</text></:content>
        </Overlay.popover>
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
  end

  defmodule FormApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Remote Form E2E" do
           size(360, 220)
           root(FormView, notifications: false, plan: "free", overlay_open: false)
         end
       ]}
    end
  end

  test "switch and radio events cross the remote native boundary" do
    port = available_port()
    {:ok, server} = GPUI.Remote.Server.start_link(app: FormApp, port: port)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: GPUI.Display.Native,
        poll_interval: 10
      )

    on_exit(fn -> Desktop.stop_process(client) end)
    on_exit(fn -> Desktop.stop_process(server) end)

    assert {:ok, %{windows: [_window]}} = GPUI.Remote.Client.mount(client)
    window_id = Desktop.window_id!("GPUI Remote Form E2E")
    Desktop.click!(window_id, 30, 26)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert true == get_in(updated, [:root, :assigns, :notifications])
    end)

    Desktop.key!(window_id, "space")

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert false == get_in(updated, [:root, :assigns, :notifications])
    end)

    Desktop.key!(window_id, "Tab")
    Desktop.key!(window_id, "Right")

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert "team" = get_in(updated, [:root, :assigns, :plan])
    end)

    Desktop.click!(window_id, 55, 112)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert true == get_in(updated, [:root, :assigns, :overlay_open])
    end)

    Desktop.key!(window_id, "Escape")

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert false == get_in(updated, [:root, :assigns, :overlay_open])
    end)
  end

  defp available_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, {_address, port}} = :inet.sockname(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
