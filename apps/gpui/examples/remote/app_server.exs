# Run with:
#   GPUI_APP_PORT=5050 mix run examples/remote/app_server.exs

project_root = Mix.Project.project_file() |> Path.dirname()
Code.require_file(Path.join(project_root, "examples/getting_started/support/controlled_form.exs"))

port = System.get_env("GPUI_APP_PORT", "5050") |> String.to_integer()

{:ok, _server} =
  GPUI.Remote.Server.start_link(
    app: GettingStarted.ControlledForm.App,
    port: port
  )

IO.puts("GPUI remote app server listening on 127.0.0.1:#{port}")
Process.sleep(:infinity)
