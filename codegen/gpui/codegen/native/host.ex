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

  @host_env "GPUI_CODEGEN_HOST"

  @doc "Returns the schema selected explicitly for this generation process."
  @spec selected() :: Registry.t()
  def selected do
    case selected_name() do
      :vanilla -> vanilla()
      :gpui_component -> gpui_component()
    end
  end

  @doc "Returns the selected host name."
  @spec selected_name() :: :vanilla | :gpui_component
  def selected_name do
    case System.get_env(@host_env, "gpui_component") do
      "vanilla" -> :vanilla
      "gpui_component" -> :gpui_component
      value -> raise ArgumentError, "unsupported #{@host_env}=#{inspect(value)}"
    end
  end

  @doc "Returns declarations for the explicitly selected generation host."
  @spec selected_components() :: [GPUI.Schema.Component.t()]
  def selected_components, do: Registry.components(selected())

  @doc "Returns native tags for the explicitly selected generation host."
  @spec selected_native_tags() :: [atom()]
  def selected_native_tags, do: Registry.native_tags(selected())

  @doc "Returns stateful declarations for the explicitly selected generation host."
  @spec selected_stateful_components() :: [GPUI.Schema.Component.t()]
  def selected_stateful_components, do: Registry.stateful_components(selected())

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
