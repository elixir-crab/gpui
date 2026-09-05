defmodule GPUI.Maintainer.Release.Version do
  @moduledoc "Typed access to coordinated package release versions."

  @packages %{
    gpui: "../../../apps/gpui",
    gpui_components: "../../../apps/gpui_components",
    gpui_native: "../../../apps/gpui_native"
  }

  @spec package_names() :: [atom()]
  def package_names, do: Map.keys(@packages)

  @spec fetch!(String.t()) :: Version.t()
  def fetch!(package) when is_binary(package) do
    name = String.to_existing_atom(package)
    path = Map.fetch!(@packages, name)

    name
    |> Mix.Project.in_project(Path.expand(path, __DIR__), fn _project ->
      Mix.Project.config() |> Keyword.fetch!(:version) |> Version.parse!()
    end)
  rescue
    ArgumentError -> raise ArgumentError, "unknown package: #{package}"
    KeyError -> raise ArgumentError, "unknown package: #{package}"
  end

  @spec prerelease?(Version.t()) :: boolean()
  def prerelease?(%Version{pre: pre}), do: pre != []
end
