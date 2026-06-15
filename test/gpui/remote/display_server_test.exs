defmodule GPUI.Remote.DisplayServerTest do
  use ExUnit.Case, async: false

  alias GPUI.Remote.DisplayProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  test "accepts multiple RemoteTCP clients" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, conn1} = start_client(port)
    {:ok, conn2} = start_client(port)

    assert {:ok, %{capabilities: capabilities1}} = SafeRPC.call(conn1, :hello, %{role: :test})
    assert {:ok, %{capabilities: capabilities2}} = SafeRPC.call(conn2, :hello, %{role: :test})

    assert :display_server in capabilities1
    assert :safe_rpc in capabilities1
    assert :display_server in capabilities2
    assert :safe_rpc in capabilities2
  end

  test "keeps serving clients after one client disconnects" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, conn1} = start_client(port)
    {:ok, conn2} = start_client(port)

    GenServer.stop(conn1)
    Process.sleep(10)

    assert {:ok, %{capabilities: capabilities}} = SafeRPC.call(conn2, :hello, %{role: :test})
    assert :display_server in capabilities
  end

  test "rejects unsupported operations" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, client} = start_client(port)

    assert {:error, {:unsupported_op, :unknown}} = SafeRPC.call(client, :unknown, %{})
  end

  test "rejects unauthorized capabilities" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)

    {:ok, client} =
      SafeRPC.Client.start_link(
        transport: SafeRPCTCP,
        host: "127.0.0.1",
        port: port,
        cap: :wrong_cap
      )

    assert {:error, :unauthorized} = SafeRPC.call(client, :hello, %{role: :test})
  end

  defp start_client(port) do
    SafeRPC.Client.start_link(
      transport: SafeRPCTCP,
      host: "127.0.0.1",
      port: port,
      cap: DisplayProtocol.capability()
    )
  end
end
