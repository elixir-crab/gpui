# GPUI

Elixir/OTP bindings and DSL experiments for [GPUI](https://www.gpui.rs).

The package name is `gpui`, with public modules under `GPUI`.

## Current direction

- Elixir views render serializable `%GPUI.Element{}` trees.
- OTP owns lifecycle through `GPUI.Runtime`.
- Rust/Rustler provides native validation and future headless utilities.
- A Rust GPUI host process will own the platform event loop.
- RustQ will generate protocol code from `GPUI.CommandSpec` as the surface grows.

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
mix ci
```

## Examples

Build the real GPUI native backend:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix gpui.native.build --real-gpui
```

Run a local native counter:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix run examples/counter.exs
```

Run a headless remote smoke check over SSH/CI:

```sh
ZED_HEADLESS=1 PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_check.exs
```

Run a RemoteTCP smoke check using the framed envelope transport:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_tcp_check.exs
```

Run the two-terminal RemoteTCP prototype:

```sh
# Terminal 1: display server, data/headless backend
GPUI_REMOTE_DISPLAY_BACKEND=data GPUI_REMOTE_PORT=4040 mix run examples/remote_display_server.exs

# Terminal 2: app runtime client
GPUI_REMOTE_HOST=127.0.0.1 GPUI_REMOTE_PORT=4040 mix run examples/remote_tcp_counter.exs
```

For a native display server, use:

```sh
GPUI_REMOTE_DISPLAY_BACKEND=native PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_display_server.exs
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
