# Image Lab

Image Lab is a focused native image utility demonstrating display-side file
selection, native decoding, bounded raster resources, and supervised,
revision-tagged palette analysis.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/image_lab/run.exs -- path/to/image.png
```

The process structure is:

```text
GPUI.Runtime
Task.Supervisor
└── analysis/export tasks
Examples.ImageLab.Coordinator
```

The coordinator subscribes to synchronized runtime updates, starts bounded
Tasks, installs the decoded raster once, and rejects stale task results by job
ID.

Inspect a running instance from IEx:

```elixir
GPUI.Runtime.info(Examples.ImageLab.Runtime)

Examples.ImageLab.Runtime
|> GPUI.Debug.format_tree()
|> IO.puts()

Examples.ImageLab.Runtime
|> GPUI.Debug.tree()
|> GPUI.Tree.find(id: "image-file-picker")
|> IO.inspect()
```
