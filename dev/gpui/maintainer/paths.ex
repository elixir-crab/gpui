defmodule GPUI.Maintainer.Paths do
  @moduledoc """
  Repository and umbrella application paths used by maintainer tooling.

  The repository root is discovered from stable workspace markers rather than
  from this module's current directory depth, so maintainer modules can move
  without changing path arithmetic.
  """

  @root_markers ["mix.exs", "Cargo.toml", "apps", "codegen"]

  @root __DIR__
        |> Path.expand()
        |> Stream.unfold(fn path ->
          parent = Path.dirname(path)
          {path, if(parent == path, do: nil, else: parent)}
        end)
        |> Enum.find(fn path ->
          Enum.all?(@root_markers, &File.exists?(Path.join(path, &1)))
        end)
        |> Kernel.||(raise "could not locate the GPUI repository root")

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
