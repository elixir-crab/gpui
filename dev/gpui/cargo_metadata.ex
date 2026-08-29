defmodule GPUI.Dev.CargoMetadata do
  @moduledoc """
  Structured Cargo package and resolved-dependency graph inspection.

  This module consumes `cargo metadata --format-version 1`; it never parses
  human-readable `cargo tree` output.
  """

  @enforce_keys [:packages_by_id, :package_ids_by_name, :dependencies_by_id]
  defstruct [:packages_by_id, :package_ids_by_name, :dependencies_by_id]

  @type package_id :: String.t()
  @type t :: %__MODULE__{
          packages_by_id: %{package_id() => map()},
          package_ids_by_name: %{String.t() => [package_id()]},
          dependencies_by_id: %{package_id() => MapSet.t(package_id())}
        }

  @doc "Loads structured Cargo metadata for exact feature arguments."
  @spec load!(Path.t(), [String.t()]) :: t()
  def load!(manifest, feature_args \\ []) do
    args =
      ["metadata", "--locked", "--format-version", "1", "--manifest-path", manifest] ++
        feature_args

    case System.cmd("cargo", args, stderr_to_stdout: true) do
      {output, 0} -> output |> JSON.decode!() |> new!()
      {output, _status} -> raise "cargo #{Enum.join(args, " ")} failed:\n#{output}"
    end
  end

  @doc "Builds a typed graph from decoded Cargo metadata JSON."
  @spec new!(map()) :: t()
  def new!(%{"packages" => packages, "resolve" => %{"nodes" => nodes}})
      when is_list(packages) and is_list(nodes) do
    packages_by_id = Map.new(packages, &{Map.fetch!(&1, "id"), &1})

    package_ids_by_name =
      packages
      |> Enum.group_by(&Map.fetch!(&1, "name"), &Map.fetch!(&1, "id"))

    dependencies_by_id =
      Map.new(nodes, fn node ->
        dependencies = node |> Map.fetch!("deps") |> Enum.map(&Map.fetch!(&1, "pkg"))
        {Map.fetch!(node, "id"), MapSet.new(dependencies)}
      end)

    %__MODULE__{
      packages_by_id: packages_by_id,
      package_ids_by_name: package_ids_by_name,
      dependencies_by_id: dependencies_by_id
    }
  end

  def new!(_metadata), do: raise(ArgumentError, "invalid Cargo metadata graph")

  @doc "Returns whether a named package transitively depends on another named package."
  @spec depends_on?(t(), String.t(), String.t()) :: boolean()
  def depends_on?(%__MODULE__{} = graph, package, dependency) do
    dependency_ids = graph |> package_ids(dependency) |> MapSet.new()

    graph
    |> package_id!(package)
    |> reachable_ids(graph)
    |> MapSet.disjoint?(dependency_ids)
    |> Kernel.not()
  end

  @doc "Returns the crate types declared by one uniquely named package."
  @spec crate_types(t(), String.t()) :: [[String.t()]]
  def crate_types(%__MODULE__{} = graph, package) do
    graph
    |> package!(package)
    |> Map.fetch!("targets")
    |> Enum.map(&Map.fetch!(&1, "crate_types"))
  end

  @doc "Returns one uniquely named package."
  @spec package!(t(), String.t()) :: map()
  def package!(%__MODULE__{} = graph, name),
    do: Map.fetch!(graph.packages_by_id, package_id!(graph, name))

  defp package_id!(graph, name) do
    case package_ids(graph, name) do
      [id] -> id
      [] -> raise ArgumentError, "Cargo package #{inspect(name)} is missing"
      ids -> raise ArgumentError, "Cargo package #{inspect(name)} is ambiguous: #{inspect(ids)}"
    end
  end

  defp package_ids(graph, name), do: Map.get(graph.package_ids_by_name, name, [])

  defp reachable_ids(root_id, graph) do
    walk([root_id], graph, MapSet.new())
    |> MapSet.delete(root_id)
  end

  defp walk([], _graph, visited), do: visited

  defp walk([id | remaining], graph, visited) do
    if MapSet.member?(visited, id) do
      walk(remaining, graph, visited)
    else
      dependencies = graph.dependencies_by_id |> Map.get(id, MapSet.new()) |> MapSet.to_list()
      walk(dependencies ++ remaining, graph, MapSet.put(visited, id))
    end
  end
end
