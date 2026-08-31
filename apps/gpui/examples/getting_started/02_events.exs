# Run from the repository root with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/02_events.exs

Code.require_file("support/events.exs", __DIR__)

children = [GettingStarted.Events.App]
{:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one)
[{_, runtime, _, _}] = Supervisor.which_children(supervisor)

IO.puts("Events is running. Press Ctrl+C twice to exit.")
GPUI.Dev.wait(runtime, files: [Path.join(__DIR__, "support/events.exs")])
