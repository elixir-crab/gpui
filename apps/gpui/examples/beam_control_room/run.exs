Code.require_file("support/beam_control_room.exs", __DIR__)

runtime = Examples.BeamControlRoom.Runtime

{:ok, _runtime} =
  GPUI.Runtime.start_link(
    name: runtime,
    app: Examples.BeamControlRoom.App
  )

{:ok, _sampler} = Examples.BeamControlRoom.Sampler.start_link(runtime: runtime)

IO.puts("BEAM Control Room is running. Press Ctrl+C twice to exit.")

GPUI.Dev.Reload.wait(runtime,
  files: [
    Path.join(__DIR__, "support/process_source.exs"),
    Path.join(__DIR__, "support/ets_source.exs"),
    Path.join(__DIR__, "support/beam_control_room.exs")
  ]
)
