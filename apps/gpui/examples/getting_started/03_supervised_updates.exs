# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/03_supervised_updates.exs

Code.require_file("support/focus_timer.exs", __DIR__)

runtime = GettingStarted.FocusTimer.Runtime

children = [
  {GettingStarted.FocusTimer.App, name: runtime},
  {GettingStarted.FocusTimer.Ticker, runtime: runtime}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("Supervised Updates is running. Press Ctrl+C twice to exit.")
GPUI.Dev.Reload.wait(runtime, files: [Path.join(__DIR__, "support/focus_timer.exs")])
