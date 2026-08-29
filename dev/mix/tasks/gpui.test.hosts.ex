defmodule Mix.Tasks.Gpui.Test.Hosts do
  @moduledoc """
  Checks the two complete native host compositions without building artifacts.

  Release-candidate validation performs the expensive source builds and
  isolated loading. This task is intentionally excluded from `mix ci`.
  """

  use Mix.Task

  @shortdoc "Checks vanilla and gpui-component native host compositions"
  @manifest "apps/gpui_native/native/gpui/Cargo.toml"

  @hosts [
    vanilla: ["--no-default-features", "--features", "vanilla-host"],
    gpui_component: ["--no-default-features", "--features", "gpui-component-host"]
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("rustq.gen", ["--check"])

    Enum.each(@hosts, fn {host, feature_args} ->
      Mix.shell().info("Checking #{host} native host")
      assert_generated_boundary!(host)
      assert_dependency_boundary!(host, feature_args)
      cargo!(["check", "--manifest-path", @manifest] ++ feature_args)
    end)
  end

  defp assert_generated_boundary!(:vanilla) do
    schema = File.read!("apps/gpui_native/native/gpui_core/src/generated/schema.rs")
    registry = File.read!("apps/gpui_native/native/gpui_core/src/generated/component_registry.rs")

    if String.contains?(schema, "ButtonComponentNode") or
         String.contains?(registry, "ComponentButton") do
      Mix.raise("vanilla generated projection contains conventional component state")
    end
  end

  defp assert_generated_boundary!(:gpui_component) do
    schema = File.read!("apps/gpui_native/native/gpui_components/src/generated/schema.rs")

    unless String.contains?(schema, "ButtonComponentNode") do
      Mix.raise("gpui-component generated projection is missing conventional components")
    end
  end

  defp assert_dependency_boundary!(host, feature_args) do
    output = cargo_output!(["tree", "--manifest-path", @manifest] ++ feature_args)
    includes_components? = String.contains?(output, "gpui-component v")

    case {host, includes_components?} do
      {:vanilla, false} -> :ok
      {:gpui_component, true} -> :ok
      {:vanilla, true} -> Mix.raise("vanilla host unexpectedly links gpui-component")
      {:gpui_component, false} -> Mix.raise("gpui-component host is missing gpui-component")
    end
  end

  defp cargo_output!(args) do
    case System.cmd("cargo", args, env: cargo_env(), stderr_to_stdout: true) do
      {output, 0} -> output
      {output, _status} -> Mix.raise("cargo #{Enum.join(args, " ")} failed:\n#{output}")
    end
  end

  defp cargo!(args) do
    {_output, status} =
      System.cmd("cargo", args,
        env: cargo_env(),
        into: IO.stream(),
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("cargo #{Enum.join(args, " ")} failed")
  end

  defp cargo_env,
    do: [{"RUST_FONTCONFIG_DLOPEN", System.get_env("RUST_FONTCONFIG_DLOPEN", "1")}]
end
