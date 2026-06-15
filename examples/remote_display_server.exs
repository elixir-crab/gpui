# Remote display server.
#
# Native display:
#   PATH="$HOME/.cargo/bin:$PATH" mix gpui.native.build --real-gpui
#   GPUI_REMOTE_DISPLAY_BACKEND=native PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_display_server.exs
#
# Headless/data display for SSH smoke checks:
#   GPUI_REMOTE_DISPLAY_BACKEND=data mix run examples/remote_display_server.exs

Code.require_file("support/remote_opts.exs", __DIR__)

port =
  System.get_env("GPUI_REMOTE_PORT", "4040")
  |> String.to_integer()

display_backend =
  System.get_env("GPUI_REMOTE_DISPLAY_BACKEND", "data")
  |> String.to_atom()

ssl = ExampleRemoteOpts.ssl_server_opts()

{:ok, _server} =
  GPUI.Remote.DisplayServer.start_link(
    port: port,
    ssl: ssl,
    display_backend: display_backend,
    display_backend_opts: [backend: display_backend]
  )

scheme = if ssl == false, do: "tcp", else: "ssl"
IO.puts("GPUI remote display server listening on #{scheme}://127.0.0.1:#{port} with display_backend=#{inspect(display_backend)}")
Process.sleep(:infinity)
