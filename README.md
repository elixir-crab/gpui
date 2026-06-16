# GPUI

Elixir/OTP bindings and DSL experiments for [GPUI](https://www.gpui.rs).

The package name is `gpui`, with public modules under `GPUI`.

## Current direction

- Elixir views render serializable `%GPUI.Element{}` trees.
- OTP owns lifecycle through `GPUI.Runtime`.
- Rust/Rustler provides the local native GPUI backend.
- Native input uses GPUI `EntityInputHandler` with focus, cursor/selection paint, clipboard, IME hooks, and UTF-16/UTF-8 offset handling.
- Remote app/display workflows use `SafeRPC` over framed TCP/SSL for safe ETF RPC, request IDs, timeouts, and capability checks.
- GPUI owns the app operation contract in `GPUI.Remote.AppProtocol`.
- Remote app servers require protocol `hello` before other operations and support app session TTL/GC.
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
PATH="$HOME/.cargo/bin:$PATH" mix compile --force --warnings-as-errors
```

The Rustler crate always compiles with upstream GPUI. Tests set `ZED_HEADLESS=1`
so the native backend exercises real GPUI without requiring a desktop display.
The Rust crate is named `gpui_nif` only to avoid Cargo ambiguity with upstream
`gpui`; the Hex package and public API remain `gpui` / `GPUI.*`.

## Examples

Build the native backend:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix compile
```

Run a local native counter:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix run examples/counter.exs
```

Run a local native image using a runtime resource cache and `%GPUI.ResourceRef{}`:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix run examples/resource_ref_image.exs
```

Run a remote smoke check over SSH/CI:

```sh
ZED_HEADLESS=1 PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_check.exs
```

Run the two-terminal remote app/display workflow:

```sh
# Terminal 1: remote OTP app server
GPUI_APP_PORT=5050 mix run examples/remote_app_server.exs

# Terminal 2: local display client
GPUI_APP_HOST=127.0.0.1 GPUI_APP_PORT=5050 PATH="$HOME/.cargo/bin:$PATH" mix run examples/local_display_client.exs
```

Remote app/display can also run over TLS/SSL. The server expects a certificate and key:

```sh
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CERTFILE=/path/to/server.pem \
GPUI_REMOTE_SSL_KEYFILE=/path/to/server.key \
GPUI_APP_PORT=5050 \
mix run examples/remote_app_server.exs
```

The display client expects the CA certificate and optional SNI name:

```sh
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CACERTFILE=/path/to/ca.pem \
GPUI_REMOTE_SSL_SERVER_NAME=localhost \
GPUI_APP_HOST=localhost \
GPUI_APP_PORT=5050 \
mix run examples/local_display_client.exs
```
