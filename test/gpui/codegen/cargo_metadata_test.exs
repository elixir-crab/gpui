defmodule GPUI.Dev.CargoMetadataTest do
  use ExUnit.Case, async: true

  alias GPUI.Dev.CargoMetadata
  alias GPUI.Dev.CargoMetadata.{Dependency, Document, Node, Package, Resolve, Target}

  test "traverses structured resolved dependencies and exposes crate types" do
    graph =
      CargoMetadata.new!(%Document{
        packages: [
          package("nif", "gpui_nif", [["cdylib"]]),
          package("core", "gpui_core", [["rlib"]]),
          package("component", "gpui_components", [["rlib"]]),
          package("upstream", "gpui-component", [["lib"]])
        ],
        resolve: %Resolve{
          nodes: [
            node("nif", ["core", "component"]),
            node("component", ["core", "upstream"]),
            node("core", []),
            node("upstream", [])
          ]
        }
      })

    assert CargoMetadata.depends_on?(graph, "gpui_nif", "gpui_core")
    assert CargoMetadata.depends_on?(graph, "gpui_nif", "gpui_components")
    assert CargoMetadata.depends_on?(graph, "gpui_nif", "gpui-component")
    refute CargoMetadata.depends_on?(graph, "gpui_core", "gpui-component")

    assert CargoMetadata.crate_types(graph, "gpui_nif") == [["cdylib"]]
    assert CargoMetadata.crate_types(graph, "gpui_core") == [["rlib"]]
    assert CargoMetadata.package_ids(graph, "gpui_core") == ["core"]
    assert CargoMetadata.unique_package_id!(graph, "gpui_nif") == "nif"
  end

  test "rejects missing and ambiguous package names" do
    graph =
      CargoMetadata.new!(%Document{
        packages: [
          package("one", "duplicate", [["rlib"]]),
          package("two", "duplicate", [["rlib"]])
        ],
        resolve: %Resolve{nodes: [node("one", []), node("two", [])]}
      })

    assert_raise ArgumentError, ~r/ambiguous/, fn ->
      CargoMetadata.unique_package_id!(graph, "duplicate")
    end

    assert_raise ArgumentError, ~r/missing/, fn ->
      CargoMetadata.depends_on?(graph, "missing", "duplicate")
    end
  end

  defp package(id, name, crate_types) do
    %Package{
      id: id,
      name: name,
      version: "0.1.0",
      targets: Enum.map(crate_types, &%Target{crate_types: &1})
    }
  end

  defp node(id, dependencies) do
    %Node{id: id, deps: Enum.map(dependencies, &%Dependency{pkg: &1})}
  end
end
