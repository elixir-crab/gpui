# Run with:
#   PATH="$HOME/.cargo/bin:$PATH" mix compile
#   GPUI_APP_HOST=127.0.0.1 GPUI_APP_PORT=5050 mix run examples/remote/display_client.exs

host = System.get_env("GPUI_APP_HOST", "127.0.0.1")
port = System.get_env("GPUI_APP_PORT", "5050") |> String.to_integer()

{:ok, client} =
  GPUI.Remote.Client.start_link(
    host: host,
    port: port,
    display: GPUI.Display.Native
  )

{:ok, %{windows: windows}} = GPUI.Remote.Client.mount(client)
IO.puts("GPUI local display connected to #{host}:#{port}; mounted #{length(windows)} window(s)")

Process.sleep(:infinity)
