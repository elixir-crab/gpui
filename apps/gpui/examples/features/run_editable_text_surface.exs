# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/features/editable_text_surface.exs

Code.require_file("editable_text_surface.exs", __DIR__)

children = [Features.EditableTextSurface.App]
{:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one)
[{_, runtime, _, _}] = Supervisor.which_children(supervisor)

IO.puts("Editable text surface is running. Press Ctrl+C twice to exit.")
GPUI.Dev.wait(runtime, files: [Path.join(__DIR__, "editable_text_surface.exs")])
