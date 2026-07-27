# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/02_focus_timer.exs

Code.require_file("support/focus_timer.exs", __DIR__)

runtime = GettingStarted.FocusTimer.Runtime

children = [
  {GettingStarted.FocusTimer.App, name: runtime},
  {GettingStarted.FocusTimer.Ticker, runtime: runtime}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("Focus Timer is running. Press Ctrl+C twice to exit.")
GPUI.Dev.wait(runtime, files: [Path.join(__DIR__, "support/focus_timer.exs")])
