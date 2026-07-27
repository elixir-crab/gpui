# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/03_settings_form.exs

Code.require_file("support/settings_form.exs", __DIR__)

children = [GettingStarted.SettingsForm.App]
{:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one)
[{_, runtime, _, _}] = Supervisor.which_children(supervisor)

IO.puts("Workspace Settings is running. Press Ctrl+C twice to exit.")
GPUI.Dev.wait(runtime, files: [Path.join(__DIR__, "support/settings_form.exs")])
