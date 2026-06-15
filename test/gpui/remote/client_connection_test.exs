defmodule GPUIRemoteClientConnectionTest do
  use ExUnit.Case, async: false

  alias GPUI.Remote.ClientConnection
  alias GPUI.Remote.Transport
  alias GPUI.Remote.Transport.TCP

  test "correlates concurrent requests by envelope id" do
    {:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :data)
    {:ok, port} = GPUI.Remote.DisplayServer.port(server)
    {:ok, conn} = ClientConnection.start_link(host: "127.0.0.1", port: port)

    requests =
      for _ <- 1..5 do
        Task.async(fn -> ClientConnection.request(conn, :hello, %{role: :test}, 1_000) end)
      end

    assert Enum.all?(requests, fn task ->
             {:ok, %{version: 1, capabilities: capabilities}} = Task.await(task)
             :display_server in capabilities
           end)
  end

  test "returns timeout errors for unanswered requests" do
    {:ok, listener} = TCP.listen(port: 0)
    {:ok, port} = TCP.port(listener)

    _silent_server =
      Task.async(fn ->
        {:ok, accepted} = TCP.accept(listener, 1_000)
        {:ok, _request} = Transport.recv(accepted, 1_000)
        Process.sleep(100)
        Transport.close(accepted)
      end)

    {:ok, conn} = ClientConnection.start_link(host: "127.0.0.1", port: port)

    assert {:error, :timeout} = ClientConnection.request(conn, :never_replies_in_test, %{}, 10)
    TCP.close(listener)
  end
end
