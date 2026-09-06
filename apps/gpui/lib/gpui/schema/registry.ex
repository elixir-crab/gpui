defmodule GPUI.Schema.Registry do
  @moduledoc """
  Immutable composition of explicitly selected declarative schema modules.

  A registry is assembled by the framework or maintainer tooling from known
  modules. It is not a runtime plugin registry and does not accept renderer
  callbacks or opaque native payloads.
  """

  alias GPUI.Schema.Component

  @enforce_keys [:modules, :components]
  defstruct modules: [], components: []

  @type schema_module :: module()
  @type provider_entry :: %{provider: schema_module(), component: Component.t()}
  @type t :: %__MODULE__{modules: [schema_module()], components: [Component.t()]}

  @doc "Builds an immutable registry directly from already-validated component declarations."
  @spec from_components([Component.t()]) :: t()
  def from_components(components) when is_list(components) do
    validate_components!(__MODULE__, components)
    %__MODULE__{modules: [], components: components}
  end

  @doc "Creates an empty immutable schema registry."
  @spec new() :: t()
  def new, do: %__MODULE__{modules: [], components: []}

  @doc "Includes one explicit schema module and rejects duplicate tags."
  @spec include(t(), schema_module()) :: t()
  def include(%__MODULE__{} = registry, module) when is_atom(module) do
    components = module.components()
    validate_components!(module, components)

    duplicates =
      registry.components
      |> Enum.map(& &1.tag)
      |> MapSet.new()
      |> MapSet.intersection(MapSet.new(components, & &1.tag))
      |> MapSet.to_list()

    if duplicates != [] do
      raise ArgumentError,
            "schema #{inspect(module)} duplicates component tags #{inspect(Enum.sort(duplicates))}"
    end

    %__MODULE__{
      modules: registry.modules ++ [module],
      components: registry.components ++ components
    }
  end

  @doc "Orders a complete registry by an explicit canonical tag manifest."
  @spec order(t(), [atom()]) :: t()
  def order(%__MODULE__{} = registry, tags) when is_list(tags) do
    current_tags = native_tags(registry)

    unless MapSet.new(current_tags) == MapSet.new(tags) and length(current_tags) == length(tags) do
      raise ArgumentError, "schema order must contain every composed component tag exactly once"
    end

    by_tag = Map.new(registry.components, &{&1.tag, &1})
    %{registry | components: Enum.map(tags, &Map.fetch!(by_tag, &1))}
  end

  @doc "Returns the composed components in declaration order."
  @spec components(t()) :: [Component.t()]
  def components(%__MODULE__{components: components}), do: components

  @doc "Returns all composed native tags in declaration order."
  @spec native_tags(t()) :: [atom()]
  def native_tags(%__MODULE__{} = registry), do: Enum.map(registry.components, & &1.tag)

  @doc "Returns the stateful components in declaration order."
  @spec stateful_components(t()) :: [Component.t()]
  def stateful_components(%__MODULE__{} = registry),
    do: Enum.filter(registry.components, & &1.stateful)

  @doc "Returns one component from the composed registry."
  @spec component!(t(), atom()) :: Component.t()
  def component!(%__MODULE__{} = registry, tag) when is_atom(tag) do
    Enum.find(registry.components, &(&1.tag == tag)) ||
      raise ArgumentError, "unknown GPUI component #{inspect(tag)}"
  end

  @doc "Returns the explicit provider module for one composed component."
  @spec provider!(t(), atom()) :: schema_module()
  def provider!(%__MODULE__{} = registry, tag) when is_atom(tag) do
    registry.modules
    |> Enum.find(fn module -> Enum.any?(module.components(), &(&1.tag == tag)) end)
    |> case do
      nil -> raise ArgumentError, "unknown GPUI component #{inspect(tag)}"
      module -> module
    end
  end

  @doc "Returns provider/component entries in composed declaration order."
  @spec entries(t()) :: [provider_entry()]
  def entries(%__MODULE__{} = registry) do
    Enum.map(registry.components, fn component ->
      %{provider: provider!(registry, component.tag), component: component}
    end)
  end

  defp validate_components!(module, components) do
    unless is_list(components) and Enum.all?(components, &match?(%Component{}, &1)) do
      raise ArgumentError, "schema #{inspect(module)} must return GPUI.Schema.Component values"
    end

    tags = Enum.map(components, & &1.tag)

    if Enum.uniq(tags) != tags do
      raise ArgumentError, "schema #{inspect(module)} contains duplicate component tags"
    end
  end
end
