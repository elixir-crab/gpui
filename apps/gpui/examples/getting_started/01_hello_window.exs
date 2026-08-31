# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/01_hello_window.exs

Code.require_file("support/hello_window.exs", __DIR__)

children = [GettingStarted.HelloWindow.App]
{:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one)
[{_, runtime, _, _}] = Supervisor.which_children(supervisor)

IO.puts("Hello GPUI is running. Press Ctrl+C twice to exit.")
GPUI.Dev.wait(runtime, files: [Path.join(__DIR__, "support/hello_window.exs")])
