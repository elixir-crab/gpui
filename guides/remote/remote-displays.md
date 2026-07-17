# Remote displays

GPUI can run the Elixir application session in one node or process and present
its windows through a native display client elsewhere. The application remains
renderer-independent; snapshots and normalized events cross the transport.

## Topology

`GPUI.Remote.Server` supervises one isolated `GPUI.Session` per mounted client.
`GPUI.Remote.Client` negotiates the protocol, mounts the application, forwards
snapshots to its configured display, and sends display events back to the
server.

The transport uses SafeRPC over framed TCP or SSL with request IDs, timeouts,
capability negotiation, and safe ETF decoding. A protocol `hello` is required
before other operations.

## Start a server

```elixir
{:ok, server} =
  GPUI.Remote.Server.start_link(
    app: MyApp.Desktop,
    port: 5050
  )
```

Each client gets its own supervised session and root assigns. A disconnected
client cannot mutate another client's application state.

## Start a native display client

```elixir
{:ok, client} =
  GPUI.Remote.Client.start_link(
    host: "127.0.0.1",
    port: 5050,
    display: GPUI.Display.Native,
    poll_interval: 16
  )

{:ok, snapshot} = GPUI.Remote.Client.mount(client)
```

The native event loop remains local to the display client. Only declarative
snapshots, resources, events, and protocol operations cross the connection.
Remote display updates use the same typed OTP message shape as local runtimes:

```elixir
:ok = GPUI.Remote.Client.subscribe(client)

receive do
  {:gpui, ^client, %GPUI.Runtime.Update{events: events, snapshot: snapshot}} ->
    # The snapshot is already synchronized to the client's display.
end
```

After synchronizing a remote snapshot, callers can wait for its local native
frame with `GPUI.Remote.Client.await_frame/3`. Native-only changes use
`GPUI.Remote.Client.frame_token/2` and `await_frame_after/4`. The remote client
remains responsive while either display barrier is pending. Subscribers are
monitored and removed when they exit.

## SSL

A server can use a certificate and key:

```bash
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CERTFILE=/path/to/server.pem \
GPUI_REMOTE_SSL_KEYFILE=/path/to/server.key \
GPUI_APP_PORT=5050 \
mix run examples/remote_app_server.exs
```

The client uses a CA certificate and optional SNI name:

```bash
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CACERTFILE=/path/to/ca.pem \
GPUI_REMOTE_SSL_SERVER_NAME=localhost \
GPUI_APP_HOST=localhost \
GPUI_APP_PORT=5050 \
mix run examples/local_display_client.exs
```

## Failure behavior

Requests have explicit IDs and timeouts. Negotiation rejects unsupported
protocol versions or capabilities. Server connection termination stops only the
owned remote session. Client reconnect behavior is isolated from the native
window loop and does not create shared application state.

Remote transport and protocol tests live under `test/integration/`; local and
remote native behavior is also exercised under Xvfb in `test/e2e/`.
