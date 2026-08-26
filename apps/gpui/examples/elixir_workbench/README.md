# Elixir Workbench

Elixir Workbench combines repository browsing and runtime logs into one coherent
developer-tool showcase:

- expandable project tree with status filtering;
- source and unified-diff presentation;
- runtime event console and event details;
- file context and diagnostics summary;
- controlled command palette;
- display-side path copying.

It replaces two visually repetitive inspector examples with a split-pane tool
that demonstrates trees, code viewers, overlays, clipboard behavior, and logs
working together.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/elixir_workbench/run.exs -- path/to/repository
```

For state-preserving view reload:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.dev examples/elixir_workbench/run.exs -- path/to/repository
```
