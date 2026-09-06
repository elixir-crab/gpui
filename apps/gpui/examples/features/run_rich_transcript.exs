# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/features/run_rich_transcript.exs

Code.require_file("rich_transcript.exs", __DIR__)

{:ok, runtime} = GPUI.Runtime.start_link(app: Features.RichTranscript.App)

IO.puts("Rich transcript is running. Press Ctrl+C twice to exit.")
GPUI.Dev.Reload.wait(runtime, files: [Path.join(__DIR__, "rich_transcript.exs")])
