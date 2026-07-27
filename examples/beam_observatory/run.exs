Code.require_file("support/beam_observatory.exs", __DIR__)

runtime = Examples.BeamObservatory.Runtime

{:ok, _runtime} =
  GPUI.Runtime.start_link(
    name: runtime,
    app: Examples.BeamObservatory.App
  )

{:ok, _sampler} = Examples.BeamObservatory.Sampler.start_link(runtime: runtime)

IO.puts("BEAM Observatory is running. Press Ctrl+C twice to exit.")

GPUI.Dev.wait(runtime,
  files: [
    Path.join(__DIR__, "support/process_source.exs"),
    Path.join(__DIR__, "support/ets_source.exs"),
    Path.join(__DIR__, "support/beam_observatory.exs")
  ]
)
