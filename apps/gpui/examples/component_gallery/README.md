# GPUI Component Gallery

The gallery follows the upstream `gpui-component` storybook structure: a
searchable sidebar, one component per story, one focused canvas, and a compact
status bar. It is reference material rather than a pretend dashboard.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/component_gallery/run.exs
```

Open one component directly:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/component_gallery/run.exs -- radio
```

Use state-preserving source reload while editing:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.dev apps/gpui/examples/component_gallery/run.exs -- tabs
```

The small status bar is the Elixir-specific addition: it reports the active
story and the latest event handled by the authoritative view process.
