# GPUI examples

The examples are organized by what they teach rather than as unrelated smoke
scripts.

## Getting started

Run these in order from the repository root:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/01_hello_window.exs
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/02_focus_timer.exs
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/03_settings_form.exs
```

For iterative UI work, replace `mix run` with `mix gpui.dev`. The development
runner recompiles explicitly watched Elixir source files and rerenders the open
window while preserving its current assigns:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.dev examples/getting_started/03_settings_form.exs
```

Native, schema, mount/default-state, and window-topology changes still require a
restart.

1. **Hello Window** introduces views, applications, and OTP supervision.
2. **Focus Timer** adds controlled events and updates from a supervised worker.
3. **Settings Form** combines form controls, dynamic styling, and a dialog.

The modules are separated into `getting_started/support/` so the examples can
be loaded and tested through `GPUI.Test` without opening native windows.

## Component gallery

The canonical native-component reference is a searchable story gallery. It
combines controls, overlays, navigation, collections, trees, and code/diff
presentation in one interactive application:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/component_gallery/run.exs
```

Pass a story ID after `--` to open it directly. See
[`component_gallery/README.md`](component_gallery/README.md) for available
stories and the live-reload workflow.

## Music library

Afterglow presents a polished desktop music collection with sidebar navigation,
controlled search and sorting, a virtualized track list, track details, and a
complete now-playing control bar:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/music_library/run.exs
```

See [`music_library/README.md`](music_library/README.md) for the controlled
playback state and deterministic catalog.

## BEAM Observatory

BEAM Observatory consolidates process and ETS inspection into one runtime
health application with summary metrics, a declarative memory map, pressure
signals, hot-process drill-down, and ranked tables:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/beam_observatory/run.exs
```

See [`beam_observatory/README.md`](beam_observatory/README.md) for its sampling
and state model.

## Elixir Workbench

Elixir Workbench combines repository navigation, source and diff presentation,
runtime logs, diagnostics, clipboard actions, and a command dialog into one
split-pane developer tool:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/elixir_workbench/run.exs -- path/to/repository
```

See [`elixir_workbench/README.md`](elixir_workbench/README.md) for its composed
feature set.

## Image palette

The image palette application decodes a local image in supervised background
work, extracts deterministic dominant colors, installs a bounded raster
resource, reports progress, and exports CSS variables:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/image_palette/run.exs -- path/to/image.png
```

See [`image_palette/README.md`](image_palette/README.md) for its worker and
analysis architecture.

## Feature examples

`features/rich_transcript.exs` composes variable-height virtualization with
consumer-produced selectable rich text. It demonstrates wrapped native shaping,
tail following, streamed height changes, prepended history, link events, and
copyable selection without introducing chat or Markdown policy:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/features/run_rich_transcript.exs
```

`features/editable_text_surface.exs` demonstrates composing a gutter, neutral
editable surface, focus control, and application-owned status state around one
persistent native text buffer:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/features/run_editable_text_surface.exs
```

`features/presentation_primitives.exs` composes bounded edge fades, explicit
frost fallbacks, and a serializable rectangle/line paint display list. The
example keeps topology and fallback policy in Elixir while native renderers own
only the GPUI interpretation.

`features/resource_ref_image.exs` demonstrates installing a raster once and
rendering a lightweight reusable resource reference:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/features/resource_ref_image.exs
```

## Remote display

Start the settings application server in one terminal:

```bash
GPUI_APP_PORT=5050 mix run examples/remote/app_server.exs
```

Then connect a native display in another:

```bash
GPUI_APP_HOST=127.0.0.1 GPUI_APP_PORT=5050 \
  RUST_FONTCONFIG_DLOPEN=1 mix run examples/remote/display_client.exs
```

The remote example reuses the same Settings Form application instead of
maintaining a separate transport-only demo.
