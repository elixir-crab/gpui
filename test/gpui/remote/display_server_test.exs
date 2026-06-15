defmodule GPUIRemoteDisplayServerTest do
  use ExUnit.Case, async: false

  alias GPUI.Remote.ClientConnection

  test "accepts multiple RemoteTCP clients" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, conn1} = ClientConnection.start_link(host: "127.0.0.1", port: port)
    {:ok, conn2} = ClientConnection.start_link(host: "127.0.0.1", port: port)

    assert {:ok, %{capabilities: capabilities1}} =
             ClientConnection.request(conn1, :hello, %{role: :test})

    assert {:ok, %{capabilities: capabilities2}} =
             ClientConnection.request(conn2, :hello, %{role: :test})

    assert :display_server in capabilities1
    assert :display_server in capabilities2
  end

  test "keeps serving clients after one client disconnects" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, conn1} = ClientConnection.start_link(host: "127.0.0.1", port: port)
    {:ok, conn2} = ClientConnection.start_link(host: "127.0.0.1", port: port)

    GenServer.stop(conn1)
    Process.sleep(10)

    assert {:ok, %{capabilities: capabilities}} =
             ClientConnection.request(conn2, :hello, %{role: :test})

    assert :display_server in capabilities
  end
end
