defmodule GPUI.Codegen.Native.Host do
  @moduledoc """
  Explicitly composes schema modules for each statically linked native host.

  Host composition is maintainer-side generation input, not runtime plugin
  discovery. Every module is named in source and produces bounded component
  declarations.
  """

  alias GPUI.Schema.Registry

  @doc "Returns the neutral vanilla-GPUI host schema."
  @spec vanilla() :: Registry.t()
  def vanilla do
    GPUI.Schema.registry()
    |> Registry.include(GPUI.Schema.Surfaces)
  end

  @doc "Returns the vanilla schema plus the official component package."
  @spec gpui_component() :: Registry.t()
  def gpui_component do
    vanilla()
    |> Registry.include(GPUI.Components.Schema.Declarations)
  end

  @doc "Returns one explicit host registry."
  @spec registry(:vanilla | :gpui_component) :: Registry.t()
  def registry(:vanilla), do: vanilla()
  def registry(:gpui_component), do: gpui_component()

  @doc "Returns declarations for one explicit host."
  @spec components(:vanilla | :gpui_component) :: [GPUI.Schema.Component.t()]
  def components(host), do: host |> registry() |> Registry.components()

  @doc "Returns native tags for one explicit host."
  @spec native_tags(:vanilla | :gpui_component) :: [atom()]
  def native_tags(host), do: host |> registry() |> Registry.native_tags()

  @doc "Returns stateful declarations for one explicit host."
  @spec stateful_components(:vanilla | :gpui_component) :: [GPUI.Schema.Component.t()]
  def stateful_components(host), do: host |> registry() |> Registry.stateful_components()

  @doc "Returns the composed gpui-component host declarations."
  @spec components() :: [GPUI.Schema.Component.t()]
  def components, do: Registry.components(gpui_component())

  @doc "Returns the composed gpui-component host native tags."
  @spec native_tags() :: [atom()]
  def native_tags, do: Registry.native_tags(gpui_component())

  @doc "Returns the composed gpui-component host stateful declarations."
  @spec stateful_components() :: [GPUI.Schema.Component.t()]
  def stateful_components, do: Registry.stateful_components(gpui_component())

  @doc "Returns versioned extensions from the composed gpui-component host."
  @spec extensions() :: [GPUI.Schema.Extension.t()]
  def extensions do
    components()
    |> Enum.flat_map(fn
      %GPUI.Schema.Component{extension: %GPUI.Schema.Extension{} = extension} -> [extension]
      _component -> []
    end)
  end
end
