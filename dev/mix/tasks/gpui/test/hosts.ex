defmodule Mix.Tasks.Gpui.Test.Hosts do
  @moduledoc """
  Checks the two complete native host compositions without building artifacts.

  Release-candidate validation performs the expensive source builds and
  isolated loading. This task is intentionally excluded from `mix ci`.
  """

  use Mix.Task

  @shortdoc "Checks vanilla and gpui-component native host compositions"

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
      GPUI.Maintainer.NativeWorkspace.check!(
        package: "gpui_nif",
        no_default_features: true,
        features: [host_feature(host)]
      )
    end)
  end

  defp host_feature(:vanilla), do: "vanilla-host"
  defp host_feature(:gpui_component), do: "gpui-component-host"

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
    graph = GPUI.Maintainer.CargoMetadata.load!(feature_args)

    assert_single_package_id!(graph, "gpui")
    assert_single_package_id!(graph, "gpui_platform")
    assert_crate_types!(graph)
    assert_dependency!(graph, "gpui_nif", "gpui_core", host)

    case host do
      :vanilla ->
        refute_dependency!(graph, "gpui_nif", "gpui_components", host)
        refute_dependency!(graph, "gpui_nif", "gpui-component", host)

      :gpui_component ->
        assert_dependency!(graph, "gpui_nif", "gpui_components", host)
        assert_dependency!(graph, "gpui_nif", "gpui-component", host)
    end
  end

  defp assert_single_package_id!(graph, package) do
    case GPUI.Maintainer.CargoMetadata.package_ids(graph, package) do
      [_id] -> :ok
      ids -> Mix.raise("expected one Cargo package ID for #{package}, got: #{inspect(ids)}")
    end
  end

  defp assert_crate_types!(graph) do
    expected = %{
      "gpui_core" => [["rlib"]],
      "gpui_components" => [["rlib"]],
      "gpui_nif" => [["cdylib"]]
    }

    Enum.each(expected, fn {package, crate_types} ->
      actual = GPUI.Maintainer.CargoMetadata.crate_types(graph, package)
      if actual != crate_types, do: Mix.raise("unexpected crate types for #{package}: #{inspect(actual)}")
    end)
  end

  defp assert_dependency!(graph, package, dependency, host) do
    unless GPUI.Maintainer.CargoMetadata.depends_on?(graph, package, dependency) do
      Mix.raise("#{host} host is missing #{dependency}")
    end
  end

  defp refute_dependency!(graph, package, dependency, host) do
    if GPUI.Maintainer.CargoMetadata.depends_on?(graph, package, dependency) do
      Mix.raise("#{host} host unexpectedly resolves #{dependency}")
    end
  end
end
