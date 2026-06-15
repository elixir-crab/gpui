defmodule GPUI.Remote.Transport.TCPTest do
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

  test "sends and receives length-prefixed ETF envelopes over SSL", context do
    certs = GPUITest.SSLCerts.generate!(context)

    {:ok, listener} =
      TCP.listen(
        port: 0,
        ssl: [
          certfile: certs.server_cert,
          keyfile: certs.server_key,
          versions: [:"tlsv1.2", :"tlsv1.3"]
        ]
      )

    {:ok, port} = TCP.port(listener)

    server =
      Task.async(fn ->
        {:ok, conn} = TCP.accept(listener, 2_000)
        {:ok, request} = Transport.recv(conn, 2_000)
        :ok = Transport.send(conn, Envelope.ok(request.id, %{secure_echo: request.payload}))
        Transport.close(conn)
        request
      end)

    {:ok, client} =
      TCP.connect(
        host: "localhost",
        port: port,
        ssl: [
          verify: :verify_peer,
          cacertfile: certs.ca_cert,
          server_name_indication: ~c"localhost",
          versions: [:"tlsv1.2", :"tlsv1.3"]
        ]
      )

    request = Envelope.request(:ping, %{message: "secure hello"}, id: 8)

    assert :ok = Transport.send(client, request)

    assert {:ok,
            %{
              kind: :response,
              id: 8,
              status: :ok,
              payload: %{secure_echo: %{message: "secure hello"}}
            }} =
             Transport.recv(client)

    assert ^request = Task.await(server)
    Transport.close(client)
    TCP.close(listener)
  end
end
