# Remote display server.
#
# Native display:
#   GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix compile
#   GPUI_REAL_GPUI=1 GPUI_REMOTE_DISPLAY_BACKEND=native PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_display_server.exs

Code.require_file("support/remote_opts.exs", __DIR__)

port =
  System.get_env("GPUI_REMOTE_PORT", "4040")
  |> String.to_integer()

display_backend =
  case System.get_env("GPUI_REMOTE_DISPLAY_BACKEND", "native") do
    "native" -> :native
    other -> raise ArgumentError, "unsupported GPUI_REMOTE_DISPLAY_BACKEND=#{inspect(other)}"
  end

ssl = ExampleRemoteOpts.ssl_server_opts()

children = [
  {GPUI.Remote.DisplayServer,
   port: port,
   ssl: ssl,
   display_backend: display_backend,
   display_backend_opts: [backend: display_backend]}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

scheme = if ssl == false, do: "tcp", else: "ssl"
IO.puts("GPUI remote display server running under an OTP supervisor on #{scheme}://127.0.0.1:#{port} with display_backend=#{inspect(display_backend)}")
Process.sleep(:infinity)
