Code.require_file("support/component_gallery.exs", __DIR__)

story = Enum.find(System.argv(), &(&1 != "--")) || "welcome"
runtime = Examples.ComponentGallery.Runtime

{:ok, _runtime} =
  GPUI.Runtime.start_link(
    name: runtime,
    app: Examples.ComponentGallery.App,
    args: %{story: story}
  )

files =
  [
    Path.join(__DIR__, "support/component_gallery.exs")
    | Path.wildcard(Path.join(__DIR__, "support/component_gallery/**/*.exs"))
  ]
  |> Enum.uniq()

IO.puts("GPUI Component Gallery is running. Press Ctrl+C twice to exit.")
GPUI.Dev.Reload.wait(runtime, files: files)
