# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/01_hello_window.exs

Code.require_file("support/hello_window.exs", __DIR__)

children = [GettingStarted.HelloWindow.App]
{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("Hello GPUI is running. Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
