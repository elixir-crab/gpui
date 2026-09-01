defmodule Mix.Tasks.Gpui.Test.ModeSwitch do
  @moduledoc "Verifies native artifact isolation across ordinary, deterministic, and desktop tests."
  use Mix.Task

  @shortdoc "Runs the no-clean native test mode-switch regression"
  @default_e2e "test/e2e/gpui/native/form_controls_test.exs"

  @impl Mix.Task
  def run(args) do
    e2e_test = parse_e2e_test!(args)

    run_mix!(["test"], test_env())
    run_mix!(["gpui.test.native"], host_env())
    run_mix!(["gpui.test.e2e", e2e_test], host_env())
    run_mix!(["test"], test_env())
    run_mix!(["gpui.test.native"], host_env())
  end

  defp parse_e2e_test!([]), do: @default_e2e
  defp parse_e2e_test!([path]), do: path

  defp parse_e2e_test!(_args) do
    Mix.raise("expected zero arguments or one focused desktop E2E test path")
  end

  defp test_env, do: [{"MIX_ENV", "test"}, {"MIX_TARGET", "host"}]
  defp host_env, do: [{"MIX_ENV", "dev"}, {"MIX_TARGET", "host"}]

  defp run_mix!(args, env) do
    {_output, status} =
      System.cmd("mix", args,
        into: IO.stream(),
        stderr_to_stdout: true,
        env: env
      )

    if status != 0, do: Mix.raise("mix #{Enum.join(args, " ")} failed")
  end
end
