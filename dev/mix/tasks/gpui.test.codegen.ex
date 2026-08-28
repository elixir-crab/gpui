defmodule Mix.Tasks.Gpui.Test.Codegen do
  @moduledoc "Runs repository-owned RustQ generator tests."
  use Mix.Task

  @shortdoc "Runs RustQ generator tests"

  @impl Mix.Task
  def run(_args) do
    System.put_env("GPUI_CODEGEN_HOST", "gpui_component")
    System.put_env("GPUI_SKIP_NATIVE", "1")
    Mix.Task.run("rustq.gen")
    Mix.Task.run("compile")
    Code.require_file("test/test_helper.exs")

    "test/gpui/codegen/**/*_test.exs"
    |> Path.wildcard()
    |> Enum.each(&Code.require_file/1)

    case ExUnit.run() do
      %{failures: 0} -> :ok
      results -> Mix.raise("codegen tests failed: #{inspect(results)}")
    end
  end
end
