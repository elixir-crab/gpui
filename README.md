# GPUI

Elixir/OTP bindings and a HEEx-style UI layer for [GPUI](https://www.gpui.rs),
with native controls provided by
[`gpui-component`](https://github.com/longbridge/gpui-component).

GPUI applications keep state and event handling in Elixir while a Rust display
owns native windows, rendering, focus, and platform input. The same application
session can be presented locally or through the remote display protocol.

> GPUI is under active development. The native application examples currently
> target x86-64 GNU/Linux.

## Installation

Add GPUI to an application with a path or Git dependency while it is under development:

```elixir
def deps do
  [{:gpui, path: "../gpui"}]
end
```

Native builds require Rust and the platform GPUI development libraries. See
[Native builds and deployment](guides/deployment/native-builds.md).

## Quick start

Run the progressive examples from the repository:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/01_hello_window.exs
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/02_focus_timer.exs
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/03_settings_form.exs
```

They cover the minimal application structure, OTP-driven updates, controlled
native components, dialogs, dynamic styling, and deterministic tests. The
larger [`process_explorer`](examples/process_explorer/README.md) example applies
those pieces to live BEAM process data.

See [Getting started](guides/introduction/getting-started.md) for installation,
native prerequisites, supervision, controlled components, and event handling.

## What GPUI provides

- Renderer-independent application sessions and typed snapshots.
- A process-global native GPUI loop that safely owns multiple runtimes and windows.
- HEEx-style templates with aliases, named slots, and schema-backed styling.
- Controlled native form controls and overlays backed directly by `gpui-component`.
- Local native and remote TCP/SSL displays.
- Public deterministic ExUnit helpers that do not require a native library or display.
- RustQ-generated Rustler contracts, decoders, element dispatch, and registry glue.
- Native Xvfb/Lavapipe interaction coverage.

## Documentation

- [Getting started](guides/introduction/getting-started.md)
- [Sessions, runtimes, and displays](guides/architecture/sessions-and-displays.md)
- [Components and styling](guides/ui/components-and-styling.md)
- [Overlays and menus](guides/ui/overlays-and-menus.md)
- [Remote displays](guides/remote/remote-displays.md)
- [Testing GPUI applications](guides/testing/testing.md)
- [Native builds and deployment](guides/deployment/native-builds.md)
- [API reference](https://hexdocs.pm/gpui/api-reference.html)

## Development

```bash
mix deps.get
mix ci
mix test_e2e
```

`mix ci` covers Elixir, generated Rust freshness, Cargo feature matrices,
Clippy, native unit tests, Dialyzer, Credo, duplication, and architecture
checks. `mix test_e2e` runs real native windows under Xvfb with Lavapipe.

## License

MIT
