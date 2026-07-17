# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/03_settings_form.exs

Code.require_file("support/settings_form.exs", __DIR__)

children = [GettingStarted.SettingsForm.App]
{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("Workspace Settings is running. Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
