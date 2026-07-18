# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/ets_table_explorer/run.exs

Code.require_file("support/ets_table_explorer.exs", __DIR__)

runtime = Examples.EtsTableExplorer.Runtime
source = Examples.EtsTableExplorer.Source

{:ok, _runtime} =
  GPUI.Runtime.start_link(
    name: runtime,
    app: Examples.EtsTableExplorer.App,
    args: %{source: source}
  )

{:ok, _supervisor} =
  Examples.EtsTableExplorer.Supervisor.start_link(
    runtime: runtime,
    source: source
  )

IO.puts("ETS Table Explorer is running. Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
