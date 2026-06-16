# Ultra-minimal RemoteTCP smoke check.
#
# Run over SSH:
#   mix run examples/remote_tcp_check.exs
#
# Expected output:
#   GPUI RemoteTCP check: PASS

Code.require_file("support/counter_app.exs", __DIR__)

{:ok, server} = GPUI.Remote.DisplayServer.start_link(port: 0, display_backend: :native)
{:ok, port} = GPUI.Remote.DisplayServer.port(server)

children = [
  {CounterApp,
   backend: :remote_tcp,
   host: "127.0.0.1",
   port: port,
   poll_interval: 10}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

pid = Process.whereis(CounterApp)
[window] = GPUI.Runtime.windows(pid)

{:ok, %{}} = GPUI.Runtime.inject_event(pid, %{window_id: window.id, event: "inc"})

deadline = System.monotonic_time(:millisecond) + 1_000

result =
  Stream.repeatedly(fn ->
    Process.sleep(10)
    [updated] = GPUI.Runtime.windows(pid)
    {_module, assigns} = updated.root
    assigns.count
  end)
  |> Enum.find(fn count -> count == 1 or System.monotonic_time(:millisecond) > deadline end)

if result == 1 do
  IO.puts("GPUI RemoteTCP check: PASS")
  System.halt(0)
else
  IO.puts(:stderr, "GPUI RemoteTCP check: FAIL")
  System.halt(1)
end
