# GPUI

Elixir/OTP bindings and DSL experiments for [GPUI](https://www.gpui.rs).

The package name is `gpui`, with public modules under `GPUI`.

## Current direction

- Elixir views render serializable `%GPUI.Element{}` trees.
- OTP owns lifecycle through `GPUI.Runtime`.
- Rust/Rustler provides the local native GPUI backend; SafeRPC/TCP provides the remote backend.
- Native input uses GPUI `EntityInputHandler` with focus, cursor/selection paint, clipboard, IME hooks, and UTF-16/UTF-8 offset handling.
- Remote display experiments use `SafeRPC` for safe ETF RPC, request IDs, timeouts, and capability checks.
- GPUI owns the display/app operation contracts in `GPUI.Remote.DisplayProtocol` and `GPUI.Remote.AppProtocol`.
- Remote servers require protocol `hello` before other operations, support session TTL/GC, and expose resource/window/event quota options.
- RustQ generates native NIF glue from project specs as the surface grows.

## Installation

After publication:

```elixir
def deps do
  [
    {:gpui, "~> 0.1.0"}
  ]
end
```

## Development

```sh
mix deps.get
mix test_unit
mix test_integration
mix ci
```

Tests are split by intent:

- `test/gpui/**` contains unit-focused tests.
- `test/integration/**` contains runtime, transport, and remote-flow integration tests.

Useful verification gates:

```sh
mix test_unit
mix test_integration
mix rustq.gen --check
GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix compile
```

The default Rustler build is a headless native shim used by CI to exercise the
NIF boundary without starting a desktop app. Set `GPUI_REAL_GPUI=1` to compile
against upstream GPUI for real windows. The Rust crate is named `gpui_nif` only
to avoid Cargo ambiguity with upstream `gpui`; the Hex package and public API
remain `gpui` / `GPUI.*`.

## Examples

Build the real GPUI native backend:

```sh
GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix compile
```

Run a local native counter:

```sh
GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix run examples/counter.exs
```

Run a local native image using a runtime resource cache and `%GPUI.ResourceRef{}`:

```sh
GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix run examples/resource_ref_image.exs
```

Run a remote smoke check over SSH/CI:

```sh
ZED_HEADLESS=1 GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_check.exs
```

Run a RemoteTCP smoke check using SafeRPC over framed TCP:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_tcp_check.exs
```

Run the preferred inverted two-terminal remote app prototype:

```sh
# Terminal 1: remote OTP app server
GPUI_APP_PORT=5050 mix run examples/remote_app_server.exs

# Terminal 2: local display client
GPUI_REAL_GPUI=1 GPUI_APP_HOST=127.0.0.1 GPUI_APP_PORT=5050 PATH="$HOME/.cargo/bin:$PATH" mix run examples/local_display_client.exs
```

Run the two-terminal RemoteTCP display-server flow:

```sh
# Terminal 1: display server
GPUI_REMOTE_DISPLAY_BACKEND=native GPUI_REMOTE_PORT=4040 mix run examples/remote_display_server.exs

# Terminal 2: app runtime client
GPUI_REMOTE_HOST=127.0.0.1 GPUI_REMOTE_PORT=4040 mix run examples/remote_tcp_counter.exs
```

For real upstream GPUI windows, compile/run with `GPUI_REAL_GPUI=1`:

```sh
GPUI_REAL_GPUI=1 GPUI_REMOTE_DISPLAY_BACKEND=native PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_display_server.exs
```

RemoteTCP can also run over TLS/SSL. The server expects a certificate and key:

```sh
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CERTFILE=/path/to/server.pem \
GPUI_REMOTE_SSL_KEYFILE=/path/to/server.key \
GPUI_REMOTE_PORT=4040 \
mix run examples/remote_display_server.exs
```

The client expects the CA certificate and optional SNI name:

```sh
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CACERTFILE=/path/to/ca.pem \
GPUI_REMOTE_SSL_SERVER_NAME=localhost \
GPUI_REMOTE_HOST=localhost \
GPUI_REMOTE_PORT=4040 \
mix run examples/remote_tcp_counter.exs
```
