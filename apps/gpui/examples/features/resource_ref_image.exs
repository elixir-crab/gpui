# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/features/resource_ref_image.exs

Code.require_file("support/resource_ref_image.exs", __DIR__)

{:ok, runtime} = GPUI.Runtime.start_link(app: Examples.ResourceRefImage.App)

:ok =
  GPUI.Runtime.put_resource(
    runtime,
    "preview",
    Examples.ResourceRefImage.raster() |> GPUI.Raster.to_payload()
  )

IO.puts("Resource Reference Image is running. Press Ctrl+C twice to exit.")
GPUI.Dev.Reload.wait(runtime, files: [Path.join(__DIR__, "support/resource_ref_image.exs")])
