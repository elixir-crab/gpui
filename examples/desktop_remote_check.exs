# Real native-display + TCP remote-session smoke check.
# Run with the same Xvfb command documented by desktop_lifecycle_check.exs.

Code.require_file("support/counter_app.exs", __DIR__)

{:ok, socket} = :gen_tcp.listen(0, [:binary, active: false])
{:ok, {_address, port}} = :inet.sockname(socket)
:ok = :gen_tcp.close(socket)

{:ok, server} = GPUI.Remote.Server.start_link(app: CounterApp, port: port)

{:ok, client} =
  GPUI.Remote.Client.start_link(
    host: "127.0.0.1",
    port: port,
    display: GPUI.Display.Native,
    poll_interval: 10
  )

{:ok, %{windows: [window]}} = GPUI.Remote.Client.mount(client)
0 = get_in(window, [:root, :assigns, :count])

{:ok, %{windows: [updated]}} =
  GPUI.Remote.Client.event(client, %{window_id: window.id, event: "inc"})

1 = get_in(updated, [:root, :assigns, :count])

:ok = GenServer.stop(client)
:ok = GenServer.stop(server)

IO.puts("GPUI desktop remote check: PASS")
