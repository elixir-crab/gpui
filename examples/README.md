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

1. **Hello Window** introduces views, applications, and OTP supervision.
2. **Focus Timer** adds controlled events and updates from a supervised worker.
3. **Settings Form** combines form controls, dynamic styling, and a dialog.

The modules are separated into `getting_started/support/` so the examples can
be loaded and tested through `GPUI.Test` without opening native windows.

## Process explorer

The first substantial example inspects live processes on the current BEAM node:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/process_explorer/run.exs
```

It combines a supervised sampler, periodic root-view messages, filtering,
sorting, a virtualized process collection, selection, and a details pane. See
[`process_explorer/README.md`](process_explorer/README.md) for its architecture.

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

`features/resource_ref_image.exs` demonstrates reusable raster resources:

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
