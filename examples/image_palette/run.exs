Code.require_file("support/image_palette.exs", __DIR__)

path =
  case System.argv() do
    [path | _arguments] -> Path.expand(path)
    [] -> ""
  end

{:ok, runtime} =
  GPUI.Runtime.start_link(
    app: Examples.ImagePalette.App,
    args: %{path: path, export_path: "palette.css"}
  )

{:ok, _supervisor} = Examples.ImagePalette.Supervisor.start_link(runtime: runtime)

if path != "" do
  GPUI.Runtime.dispatch_event(runtime, %{
    type: :click,
    window_id: 1,
    event: "load_image"
  })
end

Process.sleep(:infinity)
