# GPUI examples

The examples are organized by what they teach rather than as unrelated smoke
scripts.

## Getting started

The five small lessons introduce one concept at a time:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/01_hello_window.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/02_events.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/03_supervised_updates.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/04_controlled_form.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/05_multiple_windows.exs
```

See [`getting_started/README.md`](getting_started/README.md) for the learning
sequence and live-reload workflow.

## Component gallery

The canonical native-component reference follows the upstream
`gpui-component` storybook: a searchable sidebar and one focused component per
story, with controlled state and event ownership kept in Elixir:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/component_gallery/run.exs
```

Pass a component ID after `--` to open it directly. See
[`component_gallery/README.md`](component_gallery/README.md) for available
stories and the live-reload workflow.

## BEAM Control Room

BEAM Control Room is the OTP-specific operations example. A supervised sampler
feeds a primary process table with process drill-down, VM memory, scheduler
pressure, ports, and ETS ownership:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/beam_control_room/run.exs
```

See [`beam_control_room/README.md`](beam_control_room/README.md) for its sampling
and state model.

## Image Lab

The image palette application decodes a local image in supervised background
work, extracts deterministic dominant colors, installs a bounded raster
resource, reports progress, and exports CSS variables:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/image_lab/run.exs -- path/to/image.png
```

See [`image_lab/README.md`](image_lab/README.md) for its worker and
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
