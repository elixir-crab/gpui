defmodule GPUI.Remote.Transport.TCPTest do
  use ExUnit.Case, async: false

  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Protocol

  test "sends and receives SafeRPC frames over TCP" do
    {:ok, listener} = SafeRPCTCP.listen(port: 0)
    {:ok, port} = TCP.port(listener)

    server =
      Task.async(fn ->
        {:ok, conn} = SafeRPCTCP.accept(listener, 1_000)
        {:ok, request_payload} = SafeRPCTCP.recv(conn, 1_000)
        {:ok, request} = Protocol.decode_request(request_payload)

        :ok =
          SafeRPCTCP.send(conn, Protocol.encode_reply(request.id, {:ok, request.payload}), 1_000)

        SafeRPCTCP.close(conn)
        request
      end)

    {:ok, client} = SafeRPCTCP.connect(host: "127.0.0.1", port: port)
    request_payload = Protocol.encode_call(make_ref(), :gpui_display, :ping, %{message: "hello"})
    {:ok, request} = Protocol.decode_request(request_payload)

    assert :ok = SafeRPCTCP.send(client, request_payload, 1_000)
    assert {:ok, response_payload} = SafeRPCTCP.recv(client, 1_000)
    assert {:ok, {:ok, %{message: "hello"}}} = Protocol.decode_reply(response_payload, request.id)

    assert ^request = Task.await(server)
    SafeRPCTCP.close(client)
    SafeRPCTCP.close(listener)
  end

  test "sends and receives SafeRPC frames over SSL", context do
    certs = GPUITest.SSLCerts.generate!(context)

    {:ok, listener} =
      SafeRPCTCP.listen(
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
        {:ok, conn} = SafeRPCTCP.accept(listener, 2_000)
        {:ok, request_payload} = SafeRPCTCP.recv(conn, 2_000)
        {:ok, request} = Protocol.decode_request(request_payload)

        :ok =
          SafeRPCTCP.send(conn, Protocol.encode_reply(request.id, {:ok, request.payload}), 2_000)

        SafeRPCTCP.close(conn)
        request
      end)

    {:ok, client} =
      SafeRPCTCP.connect(
        host: "localhost",
        port: port,
        ssl: [
          verify: :verify_peer,
          cacertfile: certs.ca_cert,
          server_name_indication: ~c"localhost",
          versions: [:"tlsv1.2", :"tlsv1.3"]
        ]
      )

    request_payload =
      Protocol.encode_call(make_ref(), :gpui_display, :ping, %{message: "secure hello"})

    {:ok, request} = Protocol.decode_request(request_payload)

    assert :ok = SafeRPCTCP.send(client, request_payload, 2_000)
    assert {:ok, response_payload} = SafeRPCTCP.recv(client, 2_000)

    assert {:ok, {:ok, %{message: "secure hello"}}} =
             Protocol.decode_reply(response_payload, request.id)

    assert ^request = Task.await(server)
    SafeRPCTCP.close(client)
    SafeRPCTCP.close(listener)
  end
end
