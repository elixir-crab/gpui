defmodule GPUI.Dev.CargoMetadataTest do
  use ExUnit.Case, async: true

  alias GPUI.Dev.CargoMetadata

  test "traverses structured resolved dependencies and exposes crate types" do
    graph =
      CargoMetadata.new!(%{
        "packages" => [
          package("nif", "gpui_nif", [["cdylib"]]),
          package("core", "gpui_core", [["rlib"]]),
          package("component", "gpui_components", [["rlib"]]),
          package("upstream", "gpui-component", [["lib"]])
        ],
        "resolve" => %{
          "nodes" => [
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
  end

  test "rejects missing and ambiguous package names" do
    graph =
      CargoMetadata.new!(%{
        "packages" => [
          package("one", "duplicate", [["rlib"]]),
          package("two", "duplicate", [["rlib"]])
        ],
        "resolve" => %{"nodes" => [node("one", []), node("two", [])]}
      })

    assert_raise ArgumentError, ~r/ambiguous/, fn ->
      CargoMetadata.crate_types(graph, "duplicate")
    end

    assert_raise ArgumentError, ~r/missing/, fn ->
      CargoMetadata.depends_on?(graph, "missing", "duplicate")
    end
  end

  defp package(id, name, crate_types) do
    %{
      "id" => id,
      "name" => name,
      "targets" => Enum.map(crate_types, &%{"crate_types" => &1})
    }
  end

  defp node(id, dependencies) do
    %{"id" => id, "deps" => Enum.map(dependencies, &%{"pkg" => &1})}
  end
end
