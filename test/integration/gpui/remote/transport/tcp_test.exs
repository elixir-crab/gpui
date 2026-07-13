defmodule GPUI.Remote.Transport.TCPTest do
  use ExUnit.Case, async: false

  alias GPUI.Remote.Protocol, as: GPUIProtocol
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Protocol

  test "sends and receives SafeRPC frames over TCP" do
    assert_round_trip(port: 0)
  end

  test "sends and receives SafeRPC frames over SSL", context do
    certs = GPUITest.SSLCerts.generate!(context)

    assert_round_trip(
      port: 0,
      ssl: [
        certfile: certs.server_cert,
        keyfile: certs.server_key,
        versions: [:"tlsv1.2", :"tlsv1.3"]
      ],
      client_ssl: [
        verify: :verify_peer,
        cacertfile: certs.ca_cert,
        server_name_indication: ~c"localhost",
        versions: [:"tlsv1.2", :"tlsv1.3"]
      ]
    )
  end

  defp assert_round_trip(opts) do
    client_ssl = Keyword.get(opts, :client_ssl, false)
    listen_opts = Keyword.delete(opts, :client_ssl)
    {:ok, listener} = TCP.listen(listen_opts)
    {:ok, port} = TCP.port(listener)

    server =
      Task.async(fn ->
        {:ok, connection} = TCP.accept(listener, 2_000)
        {:ok, request_payload} = TCP.recv(connection, 2_000)
        {:ok, request} = Protocol.decode_request(request_payload)

        :ok =
          TCP.send(connection, Protocol.encode_reply(request.id, {:ok, request.payload}), 2_000)

        TCP.close(connection)
        request
      end)

    host = if client_ssl, do: "localhost", else: "127.0.0.1"
    {:ok, client} = TCP.connect(host: host, port: port, ssl: client_ssl)

    payload =
      Protocol.encode_call(make_ref(), GPUIProtocol.capability(), :ping, %{message: "hello"})

    {:ok, request} = Protocol.decode_request(payload)

    assert :ok = TCP.send(client, payload, 2_000)
    assert {:ok, response} = TCP.recv(client, 2_000)
    assert {:ok, {:ok, %{message: "hello"}}} = Protocol.decode_reply(response, request.id)
    assert ^request = Task.await(server)

    TCP.close(client)
    TCP.close(listener)
  end
end
