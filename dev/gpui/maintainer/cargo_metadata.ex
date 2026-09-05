defmodule GPUI.Maintainer.CargoMetadata do
  @moduledoc """
  Structured Cargo package and resolved-dependency graph inspection.

  This module consumes `cargo metadata --format-version 1`; it never parses
  human-readable `cargo tree` output.
  """

  alias GPUI.Maintainer.CargoMetadata.{Document, Node, Package, Resolve}

  @enforce_keys [:packages_by_id, :package_ids_by_name, :dependencies_by_id]
  defstruct [:packages_by_id, :package_ids_by_name, :dependencies_by_id]

  @type package_id :: String.t()
  @type t :: %__MODULE__{
          packages_by_id: %{package_id() => Package.t()},
          package_ids_by_name: %{String.t() => [package_id()]},
          dependencies_by_id: %{package_id() => MapSet.t(package_id())}
        }

  @doc "Loads structured Cargo metadata for exact feature arguments."
  @spec load!([String.t()]) :: t()
  def load!(feature_args \\ []) do
    feature_args
    |> GPUI.Maintainer.NativeWorkspace.metadata!()
    |> new!()
  end

  @doc "Builds a typed graph from decoded Cargo metadata."
  @spec new!(Document.t()) :: t()
  def new!(%Document{packages: packages, resolve: %Resolve{nodes: nodes}}) do
    packages_by_id = Map.new(packages, &{&1.id, &1})

    package_ids_by_name =
      packages
      |> Enum.group_by(& &1.name, & &1.id)

    dependencies_by_id =
      Map.new(nodes, fn %Node{id: id, deps: dependencies} ->
        {id, dependencies |> Enum.map(& &1.pkg) |> MapSet.new()}
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
    |> unique_package_id!(package)
    |> reachable_ids(graph)
    |> MapSet.disjoint?(dependency_ids)
    |> Kernel.not()
  end

  @doc "Returns the crate types declared by one uniquely named package."
  @spec crate_types(t(), String.t()) :: [[String.t()]]
  def crate_types(%__MODULE__{} = graph, package) do
    graph
    |> package!(package)
    |> then(fn %Package{targets: targets} -> Enum.map(targets, & &1.crate_types) end)
  end

  @doc "Returns all package IDs registered under a Cargo package name."
  @spec package_ids(t(), String.t()) :: [package_id()]
  def package_ids(%__MODULE__{} = graph, name),
    do: Map.get(graph.package_ids_by_name, name, [])

  @doc "Returns the unique package ID registered under a Cargo package name."
  @spec unique_package_id!(t(), String.t()) :: package_id()
  def unique_package_id!(%__MODULE__{} = graph, name) do
    case package_ids(graph, name) do
      [id] -> id
      [] -> raise ArgumentError, "Cargo package #{inspect(name)} is missing"
      ids -> raise ArgumentError, "Cargo package #{inspect(name)} is ambiguous: #{inspect(ids)}"
    end
  end

  @doc "Returns one uniquely named package."
  @spec package!(t(), String.t()) :: Package.t()
  def package!(%__MODULE__{} = graph, name),
    do: Map.fetch!(graph.packages_by_id, unique_package_id!(graph, name))

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
