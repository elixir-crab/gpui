# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/process_explorer/run.exs

Code.require_file("support/process_explorer.exs", __DIR__)

runtime = Examples.ProcessExplorer.Runtime

children = [
  {Examples.ProcessExplorer.App, name: runtime},
  {Examples.ProcessExplorer.Collector, runtime: runtime}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("BEAM Process Explorer is running. Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
