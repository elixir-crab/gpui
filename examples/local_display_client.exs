# Run with:
#   GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix compile
#   GPUI_REAL_GPUI=1 GPUI_APP_HOST=127.0.0.1 GPUI_APP_PORT=5050 mix run examples/local_display_client.exs

host = System.get_env("GPUI_APP_HOST", "127.0.0.1")
port = System.get_env("GPUI_APP_PORT", "5050") |> String.to_integer()
backend =
  case System.get_env("GPUI_DISPLAY_BACKEND", "native") do
    "native" -> :native
    other -> raise ArgumentError, "unsupported GPUI_DISPLAY_BACKEND=#{inspect(other)}"
  end

{:ok, display} =
  GPUI.Remote.DisplayClient.start_link(
    host: host,
    port: port,
    backend: backend
  )

{:ok, windows} = GPUI.Remote.DisplayClient.mount(display)
IO.puts("GPUI local display connected to #{host}:#{port}; mounted #{length(windows)} window(s)")

Process.sleep(:infinity)
