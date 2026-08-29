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
    schema = File.read!("apps/gpui/native/src/generated/schema.rs")
    registry = File.read!("apps/gpui/native/src/generated/component_registry.rs")

    if String.contains?(schema, "ButtonComponentNode") or
         String.contains?(registry, "ComponentButton") do
      Mix.raise("vanilla generated projection contains conventional component state")
    end
  end

  defp assert_generated_boundary!(:gpui_component) do
    schema = File.read!("apps/gpui_components/native/src/generated/schema.rs")

    unless String.contains?(schema, "ButtonComponentNode") do
      Mix.raise("gpui-component generated projection is missing conventional components")
    end
  end

  defp assert_dependency_boundary!(host, feature_args) do
    graph = GPUI.Dev.CargoMetadata.load!(@manifest, feature_args)

    case host do
      :vanilla ->
        refute_dependency!(graph, "gpui_nif", "gpui-component", host)

      :gpui_component ->
        assert_dependency!(graph, "gpui_nif", "gpui-component", host)
    end
  end

  defp assert_dependency!(graph, package, dependency, host) do
    unless GPUI.Dev.CargoMetadata.depends_on?(graph, package, dependency) do
      Mix.raise("#{host} host is missing #{dependency}")
    end
  end

  defp refute_dependency!(graph, package, dependency, host) do
    if GPUI.Dev.CargoMetadata.depends_on?(graph, package, dependency) do
      Mix.raise("#{host} host unexpectedly resolves #{dependency}")
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
