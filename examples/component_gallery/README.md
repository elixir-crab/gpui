# GPUI Component Gallery

The gallery is the canonical interactive reference for native controls exposed
by GPUI for Elixir. It groups controlled variants into searchable stories
instead of spreading one component across many standalone demo applications.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/component_gallery/run.exs
```

Open a story directly:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/component_gallery/run.exs -- collections
```

Use state-preserving source reload while editing:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.dev examples/component_gallery/run.exs -- forms
```

Available story IDs are `actions`, `forms`, `overlays`, `navigation`,
`collections`, and `code`.
