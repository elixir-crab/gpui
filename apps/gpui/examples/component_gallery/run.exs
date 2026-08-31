Code.require_file("support/component_gallery.exs", __DIR__)

story = List.first(System.argv()) || "welcome"
runtime = Examples.ComponentGallery.Runtime

{:ok, _runtime} =
  GPUI.Runtime.start_link(
    name: runtime,
    app: Examples.ComponentGallery.App,
    args: %{story: story}
  )

IO.puts("GPUI Component Gallery is running. Press Ctrl+C twice to exit.")
GPUI.Dev.wait(runtime, files: [Path.join(__DIR__, "support/component_gallery.exs")])
