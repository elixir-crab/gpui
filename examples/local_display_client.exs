# Run with:
#   PATH="$HOME/.cargo/bin:$PATH" mix gpui.native.build --real-gpui
#   GPUI_APP_HOST=127.0.0.1 GPUI_APP_PORT=5050 mix run examples/local_display_client.exs

host = System.get_env("GPUI_APP_HOST", "127.0.0.1")
port = System.get_env("GPUI_APP_PORT", "5050") |> String.to_integer()
backend = System.get_env("GPUI_DISPLAY_BACKEND", "native") |> String.to_atom()

{:ok, display} =
  GPUI.Remote.DisplayClient.start_link(
    host: host,
    port: port,
    backend: backend
  )

{:ok, windows} = GPUI.Remote.DisplayClient.mount(display)
IO.puts("GPUI local display connected to #{host}:#{port}; mounted #{length(windows)} window(s)")

Process.sleep(:infinity)
