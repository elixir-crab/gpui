# GPUI

Elixir/OTP bindings and DSL experiments for [GPUI](https://www.gpui.rs).

The package name is `gpui`, with public modules under `GPUI`.

## Current direction

- Elixir views render serializable `%GPUI.Element{}` trees.
- `GPUI.Session` owns renderer-independent windows, view assigns, resources, and rendered snapshots.
- `GPUI.Runtime` composes a session with a local `GPUI.Display`.
- Rust/Rustler provides `GPUI.Display.Native`.
- Native input uses GPUI `EntityInputHandler` with focus, cursor/selection paint, clipboard, IME hooks, and UTF-16/UTF-8 offset handling.
- Remote app/display workflows use `SafeRPC` over framed TCP/SSL for safe ETF RPC, request IDs, timeouts, and capability checks.
- GPUI owns the app operation contract in `GPUI.Remote.Protocol`.
- `GPUI.Remote.Server` isolates every application session and requires protocol `hello` before other operations.
- RustQ generates native NIF glue from project specs as the surface grows.

## Installation

After publication:

```elixir
def deps do
  [
    {:gpui, "0.1.0-rc"}
  ]
end
```

Version 0.1 provides a checksummed precompiled NIF for x86-64 GNU/Linux. Other
targets fall back to the packaged Rust source and require a Rust toolchain plus
the platform development libraries. Set `GPUI_BUILD_FROM_SOURCE=1` to force that
path explicitly.

```bash
sudo apt-get install libxkbcommon-dev libxkbcommon-x11-dev
```

Set `RUST_FONTCONFIG_DLOPEN=1` when `fontconfig.pc` is unavailable. macOS,
Windows, Linux ARM, and musl artifacts remain pending platform validation.

## Development

```sh
mix deps.get
mix test_unit
mix test_integration
mix ci
mix test_e2e
```

Tests are split by intent:

- `test/gpui/**` contains unit-focused tests.
- `test/integration/**` contains runtime, transport, and remote-flow integration tests.
- `test/e2e/**` contains real native-window tests run under Xvfb.

Useful verification gates:

```sh
mix test_unit
mix test_integration
mix rustq.gen --check
mix rust.fmt --check
mix rust.check
mix rust.clippy
mix rust.headless.clippy
mix rust.core.clippy
mix rust.e2e.clippy
mix test_e2e
mix gpui.release.check
```

The test environment compiles the NIF without `real-gpui`, so pure session,
runtime, and remote tests do not require desktop system libraries. Rust gates
cover three configurations: core-only, headless real GPUI, and the desktop
Wayland/X11 build. Setting `ZED_HEADLESS=1` selects the real-GPUI headless build
without desktop linker dependencies. Headless GPUI can exercise application
lifecycle but cannot open a platform window.

For real native-window verification on a server, install the minimal X11 build
and virtual display dependencies, then run the checked-in smoke suite:

```bash
sudo apt-get install xvfb xdotool libxkbcommon-dev libxkbcommon-x11-dev
mix test_e2e
```

The suite runs the ExUnit tests in `test/e2e/**` against real GPUI windows under
Xvfb using Mesa's Lavapipe software renderer. It verifies process-global loop
ownership, duplicate window IDs across runtimes, acknowledged lifecycle commands,
snapshot shrink, runtime shutdown isolation, and native display operation through
the TCP remote API. XTest-driven pointer and keyboard input additionally proves
button hit testing, input focus, change/key events, rapid editing, backspace,
selection, clipboard operations, controlled-value replacement, multiple input
isolation, rerendering, and user-requested window closure. No desktop environment
or window manager is required.

The Rust crate is named `gpui_nif` only to avoid Cargo ambiguity with upstream
`gpui`; the Hex package and public API remain `gpui` / `GPUI.*`.

## Precompiled release flow

Pushing a version tag such as `v0.1.0-rc` runs
`.github/workflows/precompiled-nif.yml`. It builds and attests the Linux NIF,
attaches it to the GitHub release, then generates the mandatory
`checksum-Elixir.GPUI.Native.exs` manifest from those published bytes. Download
that checksum into the repository root before building the Hex package; the
package configuration includes it automatically. Hex publication remains a
manual step after `mix gpui.release.check` passes.

## Supported UI surface

Templates support `div`, `button`, `span`, `scroll`, `list`, `item`, `icon`,
`input`, `img`, and `text`. Text and image nodes retain their own generated
native styles rather than relying only on parent styles.

The Tailwind-compatible normalizer covers display and flex layout, wrapping,
alignment, growth and shrink, colors, typography, opacity, spacing, dimensions,
minimum/maximum dimensions, borders, and radius. Unsupported classes remain in
the serialized `class` attribute instead of being silently reinterpreted.

## Examples

Build the native display:

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
