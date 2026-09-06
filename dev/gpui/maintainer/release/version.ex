defmodule GPUI.Maintainer.Release.Version do
  @moduledoc "Typed access to coordinated package release versions."

  @packages [:gpui, :gpui_components, :gpui_native]

  @spec package_names() :: [atom()]
  def package_names, do: @packages

  @spec fetch!(String.t()) :: Version.t()
  def fetch!(package) when is_binary(package) do
    name = String.to_existing_atom(package)

    unless name in @packages do
      raise ArgumentError, "unknown package: #{package}"
    end

    Mix.Project.in_project(name, GPUI.Maintainer.Paths.app(name), fn _project ->
      Mix.Project.config() |> Keyword.fetch!(:version) |> Version.parse!()
    end)
  rescue
    ArgumentError -> raise ArgumentError, "unknown package: #{package}"
  end

  @spec prerelease?(Version.t()) :: boolean()
  def prerelease?(%Version{pre: pre}), do: pre != []
end
