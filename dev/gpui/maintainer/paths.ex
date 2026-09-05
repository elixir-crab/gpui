defmodule GPUI.Maintainer.Paths do
  @moduledoc "Repository and umbrella application paths used by development tooling."

  @root __DIR__ |> Path.join("../../..") |> Path.expand()

  @spec root() :: Path.t()
  def root, do: @root

  @spec app(atom()) :: Path.t()
  def app(name) when name in [:gpui, :gpui_components, :gpui_native],
    do: Path.join([@root, "apps", Atom.to_string(name)])

  @spec support(String.t()) :: Path.t()
  def support(relative), do: Path.join([@root, "support", relative])

  @spec codegen_native() :: Path.t()
  def codegen_native, do: Path.join([@root, "codegen", "gpui", "codegen", "native"])
end
