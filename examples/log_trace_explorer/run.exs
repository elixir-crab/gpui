# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/log_trace_explorer/run.exs

Code.require_file("support/log_trace_explorer.exs", __DIR__)

runtime = Examples.LogTraceExplorer.Runtime

{:ok, _runtime} =
  GPUI.Runtime.start_link(
    name: runtime,
    app: Examples.LogTraceExplorer.App
  )

{:ok, _supervisor} =
  Examples.LogTraceExplorer.Supervisor.start_link(
    runtime: runtime,
    capacity: 10_000,
    attach_logger: true
  )

IO.puts("OTP Log and Trace Explorer is running. Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
