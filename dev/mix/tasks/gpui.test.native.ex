defmodule Mix.Tasks.Gpui.Test.Native do
  @moduledoc "Runs deterministic ExUnit tests against GPUI's native test context."
  use Mix.Task

  @shortdoc "Runs deterministic native renderer tests"

  @impl Mix.Task
  def run(args) do
    if Mix.Project.config()[:app] == :gpui_native do
      run_native_tests(args)
    else
      :ok
    end
  end

  defp run_native_tests(args) do
    test_args =
      case args do
        [] -> ["test/test/gpui/test/native"]
        args -> args
      end

    command = ["test" | test_args] ++ ["--include", "native"]

    env = [{"MIX_ENV", "test"}, {"MIX_TARGET", "native_test"}]
    run!("mix", command, env)
  end

  defp run!(executable, args, env) do
    {_output, status} =
      System.cmd(executable, args,
        into: IO.stream(),
        stderr_to_stdout: true,
        env: env
      )

    if status != 0,
      do: Mix.raise("#{executable} #{Enum.join(args, " ")} failed")
  end
end
