# RemoteTCP counter client.
#
# In another terminal, start:
#   mix run examples/remote_display_server.exs
#
# Then run:
#   mix run examples/remote_tcp_counter.exs

Code.require_file("support/counter_app.exs", __DIR__)

host = System.get_env("GPUI_REMOTE_HOST", "127.0.0.1")
port = System.get_env("GPUI_REMOTE_PORT", "4040") |> String.to_integer()

children = [
  {CounterApp,
   backend: :remote_tcp,
   host: host,
   port: port,
   poll_interval: 16}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("Counter runtime connected to GPUI remote display at #{host}:#{port}.")
IO.puts("Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
