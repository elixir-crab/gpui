defmodule GPUI.Remote.AppServerTest do
  use ExUnit.Case, async: false

  import GPUI.Template, only: [sigil_GPUI: 2]

  alias GPUI.Remote.AppProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  defmodule FormView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div>
        <input value={assigns.name} phx-change="rename" />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("rename", %{value: value}, assigns), do: {:noreply, %{assigns | name: value}}
  end

  defmodule FormApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok, %{}, [window("Remote Form", do: root(FormView, name: "old"))]}
    end
  end

  test "serves remote app snapshots and events over SafeRPC" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)
    {:ok, client} = start_client(port)

    assert {:ok, %{capabilities: capabilities}} = SafeRPC.call(client, :hello, %{})
    assert :app_server in capabilities

    assert {:ok, %{windows: [%{id: 1, root: %{tree: mounted_tree}}]}} =
             SafeRPC.call(client, :mount, %{})

    assert mounted_tree.type == :div

    assert {:ok, %{windows: [%{root: %{assigns: %{name: "new"}}}]}} =
             SafeRPC.call(client, :event, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "new"
             })
  end

  test "display client mounts and forwards events to remote app server" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)

    {:ok, display} =
      GPUI.Remote.DisplayClient.start_link(host: "127.0.0.1", port: port, backend: :data)

    assert {:ok, [%{id: 1}]} = GPUI.Remote.DisplayClient.mount(display)

    assert {:ok, [%{root: %{assigns: %{name: "client"}}}]} =
             GPUI.Remote.DisplayClient.event(display, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "client"
             })
  end

  test "display client reconnects and remounts after app server restart" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)

    {:ok, display} =
      GPUI.Remote.DisplayClient.start_link(host: "127.0.0.1", port: port, backend: :data)

    assert {:ok, [%{id: 1}]} = GPUI.Remote.DisplayClient.mount(display)

    GenServer.stop(server)
    {:ok, _server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: port)

    assert {:ok, [%{root: %{assigns: %{name: "after-reconnect"}}}]} =
             GPUI.Remote.DisplayClient.event(display, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "after-reconnect"
             })
  end

  test "rejects unauthorized app clients" do
    {:ok, server} = GPUI.Remote.AppServer.start_link(app: FormApp, port: 0)
    {:ok, port} = GPUI.Remote.AppServer.port(server)

    {:ok, client} =
      SafeRPC.Client.start_link(
        transport: SafeRPCTCP,
        host: "127.0.0.1",
        port: port,
        cap: :wrong_cap
      )

    assert {:error, :unauthorized} = SafeRPC.call(client, :hello, %{})
  end

  defp start_client(port) do
    SafeRPC.Client.start_link(
      transport: SafeRPCTCP,
      host: "127.0.0.1",
      port: port,
      cap: AppProtocol.capability()
    )
  end
end
