# Run with:
#   GPUI_APP_PORT=5050 mix run examples/remote/app_server.exs

Code.require_file("../getting_started/support/settings_form.exs", __DIR__)

port = System.get_env("GPUI_APP_PORT", "5050") |> String.to_integer()

{:ok, _server} =
  GPUI.Remote.Server.start_link(
    app: GettingStarted.SettingsForm.App,
    port: port
  )

IO.puts("GPUI remote app server listening on 127.0.0.1:#{port}")
Process.sleep(:infinity)
