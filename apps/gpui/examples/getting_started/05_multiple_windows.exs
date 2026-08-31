# Run from the repository root with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/05_multiple_windows.exs

Code.require_file("support/multiple_windows.exs", __DIR__)

children = [GettingStarted.MultipleWindows.App]
{:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one)
[{_, runtime, _, _}] = Supervisor.which_children(supervisor)

IO.puts("Multiple Windows is running. Press Ctrl+C twice to exit.")
GPUI.Dev.wait(runtime, files: [Path.join(__DIR__, "support/multiple_windows.exs")])
