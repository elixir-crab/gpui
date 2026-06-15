defmodule GPUIRemoteTransportTCPTest do
  use ExUnit.Case, async: false

  alias GPUI.Protocol.Envelope
  alias GPUI.Remote.Transport
  alias GPUI.Remote.Transport.TCP

  test "sends and receives length-prefixed ETF envelopes over TCP" do
    {:ok, listener} = TCP.listen(port: 0)
    {:ok, port} = TCP.port(listener)

    server =
      Task.async(fn ->
        {:ok, conn} = TCP.accept(listener, 1_000)
        {:ok, request} = Transport.recv(conn, 1_000)
        :ok = Transport.send(conn, Envelope.ok(request.id, %{echo: request.payload}))
        Transport.close(conn)
        request
      end)

    {:ok, client} = TCP.connect(host: "127.0.0.1", port: port)
    request = Envelope.request(:ping, %{message: "hello"}, id: 7)

    assert :ok = Transport.send(client, request)

    assert {:ok, %{kind: :response, id: 7, status: :ok, payload: %{echo: %{message: "hello"}}}} =
             Transport.recv(client)

    assert ^request = Task.await(server)
    Transport.close(client)
    TCP.close(listener)
  end
end
