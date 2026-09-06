Code.require_file("support/image_lab.exs", __DIR__)

path =
  case System.argv() do
    [path | _arguments] -> Path.expand(path)
    [] -> ""
  end

{:ok, runtime} =
  GPUI.Runtime.start_link(
    name: Examples.ImageLab.Runtime,
    app: Examples.ImageLab.App,
    args: %{path: path, export_path: "palette.css"}
  )

{:ok, _supervisor} = Examples.ImageLab.Supervisor.start_link(runtime: runtime)

if path != "" do
  {:ok, _event, _snapshot} =
    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: 1,
      event: "load_image"
    })
end

GPUI.Dev.Reload.wait(runtime,
  files: [
    Path.join(__DIR__, "support/analysis.exs"),
    Path.join(__DIR__, "support/image_lab.exs")
  ]
)
