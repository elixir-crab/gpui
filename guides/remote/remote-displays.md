# Remote displays

GPUI can run the Elixir application session in one node or process and present
its windows through a native display client elsewhere. The application remains
renderer-independent; snapshots and normalized events cross the transport.

## Topology

`GPUI.Remote.Server` supervises one isolated remote session coordinator and
`GPUI.Session` per mounted client. Session work is delegated out of the central
server and connection owner, so a slow mount or event in one session does not
delay unrelated sessions—even when requests share one transport connection.
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
    port: 5050,
    max_in_flight_requests_per_connection: 64,
    max_in_flight_requests_per_session: 16
  )
```

Each client gets its own supervised session and root assigns. A disconnected
client cannot mutate another client's application state. The request limits
shown above are the defaults; both accept positive values up to 4,096.

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
Display-side file pickers read bounded bytes on the client and send those bytes
with an operation ID; they never claim that a client-local path is readable by
the application server. Clipboard buttons likewise write to the display
client's clipboard. Application-side filesystem work has the opposite
semantics: paths identify files on the application server. The
`git_repository_browser` example makes that distinction explicit instead of
presenting a server-local directory as a remote-client directory. Source-backed
virtual-list range requests also originate on the display and cross the same
event channel, allowing the server to return only an overscanned slice.

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
mix run examples/remote/app_server.exs
```

The client uses a CA certificate and optional SNI name:

```bash
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CACERTFILE=/path/to/ca.pem \
GPUI_REMOTE_SSL_SERVER_NAME=localhost \
GPUI_APP_HOST=localhost \
GPUI_APP_PORT=5050 \
mix run examples/remote/display_client.exs
```

## Failure behavior

Requests have explicit IDs and timeouts. Negotiation rejects unsupported
protocol versions or capabilities. Mounts and events carry stable operation IDs,
so retrying after a lost reply does not mount twice or apply the same event
twice. A disconnected session remains resumable until its configured session
TTL expires; terminating a connection immediately removes only its connection
owner.

Display events drained during an outage are retained in a bounded 1,024-event
client queue and retried in order after reconnection. If that bound is exceeded,
the newest events are retained. Poll timers use generation tokens, while each
session coordinator owns and resets its expiry timer directly. Stale timer
messages cannot create duplicate polling loops or expire a recently active
session. Work above either configured in-flight limit is rejected with
`{:error, :overloaded}` before it reaches the session. Automatically forwarded
display events remain in the client's bounded queue and retry on a later poll.
Client reconnect behavior remains isolated from the native window loop and does
not create shared application state.

Remote transport and protocol tests live under `test/integration/`; local and
remote native behavior is also exercised under Xvfb in `test/e2e/`.
