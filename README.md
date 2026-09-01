# GPUI

**Native desktop applications in Elixir, rendered by [GPUI](https://www.gpui.rs).**

GPUI keeps application state, window topology, UI declarations, and event
handling in Elixir. Rust owns the native event loop, windows, rendering, focus,
IME, accessibility, and latency-sensitive interaction. Conventional controls
are provided separately by [`gpui_components`](apps/gpui_components/README.md)
and rendered with
[`gpui-component`](https://github.com/longbridge/gpui-component).

> **Elixir owns the application. GPUI owns the native interaction. Snapshots
> connect them.**

One declarative application can run against a local native display, a
deterministic test display, or a native display on another machine.

GPUI 0.2.0-rc.1 is a public release candidate. Current precompiled platform
support targets Linux x86-64 under X11; Apple silicon macOS and x86-64 Windows
are source-build development targets. APIs may still change before 0.2.0. See
[Platform support and development status](apps/gpui/guides/internals/platform-support.md).

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
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/01_hello_window.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/02_events.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/03_supervised_updates.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/04_controlled_form.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/05_multiple_windows.exs
```

See [Your first application](apps/gpui/guides/getting-started/first-application.md) for supervision,
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

See [Sessions, snapshots, and displays](apps/gpui/guides/concepts/sessions-snapshots-and-displays.md),
[Remote displays](apps/gpui/guides/remote/remote-displays.md), and
[Testing GPUI applications](apps/gpui/guides/testing/overview.md).

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

Read more in [Editable text internals](apps/gpui/guides/internals/editable-text-internals.md),
[Accessibility internals](apps/gpui/guides/internals/accessibility.md),
and [UI components](apps/gpui/guides/ui/components.md).

## Examples

| Example | What it demonstrates |
| --- | --- |
| [Rich transcript](apps/gpui/examples/features/rich_transcript.exs) | Variable-height virtualization, selectable rich text, links, and a native composer |
| [BEAM Control Room](apps/gpui/examples/beam_control_room/README.md) | Supervised runtime sampling driving controlled native views |
| [Image Lab](apps/gpui/examples/image_lab/README.md) | Display-side file reads, image decoding, and bounded raster resources |
| [Component Gallery](apps/gpui/examples/component_gallery/README.md) | Canonical component states, combinations, and accessibility behavior |

Run the `gpui.dev` Mix task with the larger examples for state-preserving
Elixir source reload. See the [examples index](apps/gpui/examples/README.md) for the
complete catalog.

## Packages

The repository is a Mix umbrella with three independently publishable packages
and one private maintainer application:

| Package | Purpose |
| --- | --- |
| [`gpui`](apps/gpui) | Renderer-independent applications, sessions, snapshots, schemas, remote displays, and test APIs |
| [`gpui_components`](apps/gpui_components) | Conventional declarative controls backed by `gpui-component` |
| [`gpui_native`](apps/gpui_native) | RustlerPrecompiled vanilla and `gpui-component` native hosts |
| Root tooling | Private RustQ generation, repository checks, native testing, and release validation |

RustQ runs only in the source umbrella. Generated Elixir and Rust are committed,
and supported consumer targets download checksum-verified NIF archives through
`RustlerPrecompiled`; consumer compilation does not run RustQ.

## Installation

For a renderer-independent application or remote server:

```elixir
def deps do
  [
    {:gpui, "== 0.2.0-rc.1"}
  ]
end
```

For a native application using conventional controls:

```elixir
def deps do
  [
    {:gpui, "== 0.2.0-rc.1"},
    {:gpui_components, "== 0.2.0-rc.1"},
    {:gpui_native, "== 0.2.0-rc.1"}
  ]
end
```

Select the `gpui-component` host when component elements are used:

```elixir
# config/config.exs
config :gpui_native, GPUI.Native, host: :gpui_component
```

Use `host: :vanilla` for the complete vanilla-GPUI host. Exactly one host
artifact is loaded; the component-capable artifact statically links its
renderer rather than attaching a second native library at runtime.
Renderer-independent sessions, remote servers, and `GPUI.Test`
require neither Rust nor a native library or display server. See
[Native builds and deployment](apps/gpui/guides/deployment/native-builds.md).


## Documentation

- [Documentation home](apps/gpui/guides/documentation.md)
- [Your first application](apps/gpui/guides/getting-started/first-application.md)
- [UI components](apps/gpui/guides/ui/components.md)
- [Templates and elements](apps/gpui/guides/ui/templates-and-elements.md)
- [Forms and controls](apps/gpui/guides/ui/forms-and-controls.md)
- [Collections and data views](apps/gpui/guides/ui/collections-and-data-views.md)
- [Text and editing](apps/gpui/guides/ui/text-and-editing.md)
- [Editable text surfaces](apps/gpui/guides/ui/editable-text.md)
- [Layout, styling, and presentation](apps/gpui/guides/ui/layout-styling-and-presentation.md)
- [Presentation primitives](apps/gpui/guides/ui/presentation-primitives.md)
- [Commands and keyboard shortcuts](apps/gpui/guides/ui/commands-and-shortcuts.md)
- [Overlays and menus](apps/gpui/guides/ui/overlays-and-menus.md)
- [Testing GPUI applications](apps/gpui/guides/testing/overview.md)
- [Application tests](apps/gpui/guides/testing/application-tests.md)
- [Deterministic native tests](apps/gpui/guides/testing/native-tests.md)
- [Desktop E2E and visual evidence](apps/gpui/guides/testing/desktop-e2e.md)
- [Platform support and development status](apps/gpui/guides/internals/platform-support.md)
- [API reference](https://hexdocs.pm/gpui/api-reference.html)

## Development

```bash
mix deps.get
mix gpui.test.packages
mix ci
MIX_ENV=e2e xvfb-run -a dbus-run-session -- mix test --only e2e apps/gpui_native/test/e2e
```

`mix gpui.test.packages` builds the three public Hex payloads and compiles their
exact unpacked contents in clean downstream consumers, with repository-only
tooling and Cargo unavailable. `mix ci` includes this package-isolation gate and
covers Elixir, generated Rust freshness, Cargo feature matrices,
Clippy, native unit tests, Dialyzer, Credo, duplication, and architecture
checks. Hosted push validation splits the renderer-independent and native
checks; the full native interaction and release-package suite is an explicit
`Release candidate` workflow rather than a scheduled or per-push job. See
[Testing GPUI applications](apps/gpui/guides/testing/overview.md) for native
Xvfb/Lavapipe interaction coverage.

## License

MIT
