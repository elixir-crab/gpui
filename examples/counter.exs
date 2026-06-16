# Run with:
#   GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix compile
#   GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix run examples/counter.exs

Code.require_file("support/counter_app.exs", __DIR__)

children = [
  {CounterApp, backend: :native, poll_interval: 16}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("Counter running under an OTP supervisor. Click + in the GPUI window. Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
