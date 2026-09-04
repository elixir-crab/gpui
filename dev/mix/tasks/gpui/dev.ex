defmodule Mix.Tasks.Gpui.Dev do
  use Mix.Task

  @shortdoc "Runs a GPUI example with state-preserving Elixir source reload"

  @moduledoc """
  Runs an example script with GPUI development source reloading enabled.

      mix gpui.dev apps/gpui/examples/beam_control_room/run.exs
      mix gpui.dev apps/gpui/examples/image_lab/run.exs -- path/to/image.png

  The script must call `GPUI.Dev.wait/2` with its runtime and source files.
  Changes to those files are compiled in the running BEAM, then the existing
  windows are rerendered with their current assigns. Native/schema changes and
  application remount changes still require a restart.
  """

  @impl Mix.Task
  def run(args) do
    {options, argv, invalid} = OptionParser.parse(args, strict: [no_compile: :boolean])

    if invalid != [], do: Mix.raise("invalid gpui.dev options: #{inspect(invalid)}")

    case argv do
      [script | script_args] ->
        run_script(script, script_args, options)

      [] ->
        Mix.raise(
          "expected an example script, for example: mix gpui.dev apps/gpui/examples/beam_control_room/run.exs"
        )
    end
  end

  defp run_script(script, script_args, options) do
    script = Path.expand(script)
    unless File.regular?(script), do: Mix.raise("GPUI example script not found: #{script}")

    unless options[:no_compile], do: Mix.Task.run("compile", [])

    ensure_native_available!()
    System.put_env("GPUI_DEV_RELOAD", "1")
    System.argv(script_args)
    Code.eval_file(script)
  end

  defp ensure_native_available! do
    if Application.get_env(:gpui, :build_native, false) and not GPUI.Native.available?() do
      Mix.raise("""
      the native GPUI runtime is not available in this build.

      Build it first with the project toolchain, then rerun with --no-compile if desired.
      Source reload recompiles only Elixir files; native/schema changes still require a restart.
      """)
    end
  end
end
