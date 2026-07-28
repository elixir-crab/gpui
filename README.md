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

Desktop applications explicitly enable the native display outside tests:

```elixir
# config/config.exs
config :gpui, build_native: config_env() != :test
```

Renderer-independent sessions, remote servers, and `GPUI.Test` do not require
that setting, Rust, a native library, or a display server. Native builds require
Rust and the platform GPUI development libraries. See
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
searchable [`component_gallery`](examples/component_gallery/README.md) is the
canonical interactive reference for component states and combinations. The
larger [`music_library`](examples/music_library/README.md),
[`beam_observatory`](examples/beam_observatory/README.md),
[`elixir_workbench`](examples/elixir_workbench/README.md), and
[`image_palette`](examples/image_palette/README.md) examples apply those pieces
to music interaction, runtime observability, repository and log workflows, and
image analysis.

See [Getting started](guides/introduction/getting-started.md) for installation,
native prerequisites, supervision, controlled components, and event handling.

## What GPUI provides

- Renderer-independent application sessions and typed snapshots.
- A process-global native GPUI loop that safely owns multiple runtimes and windows.
- HEEx-style templates with aliases, named slots, and schema-backed styling.
- Controlled native form controls, progress, display-side file/clipboard actions, overlays, source-backed lists/trees/data tables, monospaced code/diff viewing, and platform-aware window commands.
- Persistent native Rope text buffers with explicit UTF-16 coordinates, revisioned atomic edits, selections, and undo/redo primitives.
- Common image decoding, validated rasters, and reusable local or remote resources.
- Local native and remote TCP/SSL displays.
- Public deterministic ExUnit helpers that do not require a native library or display.
- RustQ-generated Rustler contracts, decoders, element dispatch, and registry glue.
- Native Xvfb/Lavapipe interaction coverage.

## Documentation

- [Getting started](guides/introduction/getting-started.md)
- [Sessions, runtimes, and displays](guides/architecture/sessions-and-displays.md)
- [Editable text primitives](guides/architecture/editable-text-primitives.md)
- [Components and styling](guides/ui/components-and-styling.md)
- [Commands and keyboard shortcuts](guides/ui/commands-and-shortcuts.md)
- [Overlays and menus](guides/ui/overlays-and-menus.md)
- [Remote displays](guides/remote/remote-displays.md)
- [Testing GPUI applications](guides/testing/testing.md)
- [Native builds and deployment](guides/deployment/native-builds.md)
- [API reference](https://hexdocs.pm/gpui/api-reference.html)

## Development

```bash
mix deps.get
mix ci
MIX_ENV=e2e xvfb-run -a dbus-run-session -- mix test --only e2e test/e2e
```

`mix ci` covers Elixir, generated Rust freshness, Cargo feature matrices,
Clippy, native unit tests, Dialyzer, Credo, duplication, and architecture
checks. The standard ExUnit command runs real native windows under Xvfb with
Lavapipe; Xvfb and D-Bus are platform infrastructure rather than a custom Mix
test runner.

## License

MIT
