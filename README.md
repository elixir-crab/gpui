# GPUI

**Native desktop applications in Elixir, rendered by [GPUI](https://www.gpui.rs).**

GPUI keeps application state, window topology, UI declarations, and event
handling in Elixir. Rust owns the native event loop, windows, rendering, focus,
IME, accessibility, and latency-sensitive interaction. Native controls come
from [`gpui-component`](https://github.com/longbridge/gpui-component).

> **Elixir owns the application. GPUI owns the native interaction. Snapshots
> connect them.**

One declarative application can run against a local native display, a
deterministic test display, or a native display on another machine.

GPUI is private and unreleased. Current platform evidence targets Linux x86-64
under X11; Apple silicon macOS and x86-64 Windows are source-build development
targets. Internal APIs may change directly while the architecture is being
built. See [Platform support and development status](guides/internals/platform-support.md).

## Write native UI like Elixir

```elixir
defmodule CounterView do
  use GPUI.View
  alias GPUI.UI

  def render(assigns) do
    ~GPUI"""
    <div class="flex grow flex-col items-center justify-center w-full gap-4 bg-slate-950">
      <text class="text-3xl font-semibold text-white">Count: {assigns.count}</text>
      <UI.button id="increment" label="Increment" variant="primary" phx-click="increment" />
    </div>
    """
  end

  def handle_event("increment", _event, assigns) do
    {:noreply, %{assigns | count: assigns.count + 1}}
  end
end

defmodule CounterApp do
  use GPUI.Application

  def mount(_args) do
    {:ok,
     [
       window "Counter" do
         size(420, 280)
         root(CounterView, count: 0)
       end
     ]}
  end
end
```

`assigns` remains authoritative Elixir state. Pointer, keyboard, and accessible
activation return through the same typed event path; Rust does not become a
second application state system.

Run the progressive examples from the repository:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/01_hello_window.exs
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/02_focus_timer.exs
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/03_settings_form.exs
```

See [Your first application](guides/getting-started/first-application.md) for supervision,
controlled components, event handling, and native prerequisites.

## Why GPUI

- **Native, not a web view.** GPUI provides native layout, text shaping,
  windows, focus, platform input, and AccessKit semantics without a DOM or
  embedded browser runtime.
- **Declarative, not raw Rust bindings.** Elixir renders bounded, serializable
  snapshots; displays interpret them and return strict typed events.
- **OTP remains the application runtime.** Controlled values stay in Elixir.
  Native code retains only interaction mechanics such as focus, IME, text
  selection, drag sessions, and measurement.

## One application, multiple displays

```text
GPUI.Application
        │
        ▼
GPUI.WindowSpec
        │
        ▼
GPUI.Session ──────► GPUI.Snapshot
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
       Native display  Test display  Remote display
```

A native display presents real windows. A test display makes view behavior
deterministic without Rust or a display server. The remote protocol can keep
the authoritative session on one machine while another presents its native
windows. Dynamic multi-window topology remains snapshot-driven in every mode.

See [Sessions, snapshots, and displays](guides/concepts/sessions-snapshots-and-displays.md),
[Remote displays](guides/remote/remote-displays.md), and
[Testing GPUI applications](guides/testing/overview.md).

## Highlights

- **Persistent native text:** Rope buffers, zero-based UTF-16 positions,
  revisioned atomic transactions, plural selections, undo/redo, IME, shaped
  style runs, and asynchronous geometry. `<text_surface>` supports editors and
  auto-growing composers without moving document policy into Rust.
- **Rich virtualized content:** variable-height collections preserve scroll
  anchors while items are prepended or remeasured; selectable rich text adds
  native shaping, clipboard behavior, and keyboard-activatable opaque links.
- **Native semantics across displays:** accessibility roles and states, stable
  identities, bounded clipboard/file/drop values, and unified pointer,
  keyboard, and AccessKit activation all travel through renderer-independent
  snapshots and typed events.
- **A small handwritten native core:** RustQ generates Rustler declarations,
  decoders, renderer and style dispatch, and registry glue from the Elixir
  schema. Handwritten Rust is reserved for platform integration,
  reconciliation, and latency-sensitive native mechanics.

Read more in [Editable text internals](guides/internals/editable-text.md),
[Accessibility internals](guides/internals/accessibility.md),
and [UI components](guides/ui/components.md).

## Examples

| Example | What it demonstrates |
| --- | --- |
| [Rich transcript](examples/features/rich_transcript.exs) | Variable-height virtualization, selectable rich text, links, and a native composer |
| [Elixir Workbench](examples/elixir_workbench/README.md) | Trees, code and diff views, split panes, overlays, clipboard, and logs |
| [BEAM Observatory](examples/beam_observatory/README.md) | Supervised runtime sampling driving controlled native views |
| [Afterglow](examples/music_library/README.md) | A polished consumer UI with native controls and responsive layout |
| [Image Palette](examples/image_palette/README.md) | Display-side file reads, image decoding, and bounded raster resources |
| [Component Gallery](examples/component_gallery/README.md) | Canonical component states, combinations, and accessibility behavior |

Run the `gpui.dev` Mix task with the larger examples for state-preserving
Elixir source reload. See the [examples index](examples/README.md) for the
complete catalog.

## Installation

Add GPUI with a path or Git dependency while it is under development:

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

Renderer-independent sessions, remote servers, and `GPUI.Test` require neither
Rust nor a native library or display server. Native builds require the pinned
Rust toolchain and GPUI platform libraries. See
[Native builds and deployment](guides/deployment/native-builds.md).

## Documentation

- [Documentation home](guides/documentation.md)
- [Your first application](guides/getting-started/first-application.md)
- [UI components](guides/ui/components.md)
- [Templates and elements](guides/ui/templates-and-elements.md)
- [Forms and controls](guides/ui/forms-and-controls.md)
- [Collections and data views](guides/ui/collections-and-data-views.md)
- [Text and editing](guides/ui/text-and-editing.md)
- [Layout, styling, and presentation](guides/ui/layout-styling-and-presentation.md)
- [Commands and keyboard shortcuts](guides/ui/commands-and-shortcuts.md)
- [Overlays and menus](guides/ui/overlays-and-menus.md)
- [Testing GPUI applications](guides/testing/overview.md)
- [Platform support and development status](guides/internals/platform-support.md)
- [API reference](https://hexdocs.pm/gpui/api-reference.html)

## Development

```bash
mix deps.get
mix ci
MIX_ENV=e2e xvfb-run -a dbus-run-session -- mix test --only e2e test/e2e
```

`mix ci` covers Elixir, generated Rust freshness, Cargo feature matrices,
Clippy, native unit tests, Dialyzer, Credo, duplication, and architecture
checks. Hosted push validation splits the renderer-independent and native
checks; the full native interaction and release-package suite is an explicit
`Release candidate` workflow rather than a scheduled or per-push job. See
[Testing GPUI applications](guides/testing/overview.md) for native
Xvfb/Lavapipe interaction coverage.

## License

MIT
