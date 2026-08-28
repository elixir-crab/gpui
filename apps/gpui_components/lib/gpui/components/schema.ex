defmodule GPUI.Components.Schema do
  @moduledoc """
  Conventional component declarations owned by the `gpui_components` package.

  The current native protocol remains coordinated with `GPUI.Schema` while the
  declarations migrate package by package. This module is the stable schema
  owner consumed by component builders and explicit host composition.
  """

  @behaviour GPUI.Schema.Provider

  alias GPUI.Schema.ComponentDocs

  @components GPUI.Components.Schema.Declarations.components()

  @registry GPUI.Schema.Registry.from_components(GPUI.Schema.Surfaces.components() ++ @components)

  @impl true
  @doc "Returns conventional component declarations in protocol order."
  @spec components() :: [GPUI.Schema.Component.t()]
  def components, do: @components

  @doc "Returns one conventional or component-package-authored surface declaration."
  @spec component!(atom()) :: GPUI.Schema.Component.t()
  def component!(tag) when is_atom(tag), do: GPUI.Schema.Registry.component!(@registry, tag)

  @doc "Returns defaults for one conventional component."
  @spec defaults(atom()) :: map()
  def defaults(tag) do
    tag
    |> component!()
    |> Map.fetch!(:attrs)
    |> Enum.reduce(%{}, fn
      {name, {:default, _type, value}}, defaults -> Map.put(defaults, name, value)
      {name, :boolean}, defaults -> Map.merge(defaults, %{name => false})
      {name, :string_list}, defaults -> Map.put(defaults, name, [])
      {_name, _type}, defaults -> defaults
    end)
  end

  @doc "Applies conventional component defaults to an assigns map."
  @spec apply_defaults(map(), atom()) :: map()
  def apply_defaults(assigns, tag) when is_map(assigns),
    do: defaults(tag) |> Map.merge(assigns)

  @doc "Validates conventional component assigns through the shared protocol validator."
  @spec validate_component_assigns!(map(), atom(), [atom()]) :: map()
  def validate_component_assigns!(assigns, tag, extra_attrs \\ []) do
    component = component!(tag)
    GPUI.Schema.validate_component_assigns!(assigns, component, extra_attrs)
  end

  @doc "Returns generated public option documentation for a component tag."
  @spec component_options_doc(atom()) :: String.t()
  def component_options_doc(tag), do: tag |> component!() |> ComponentDocs.options_doc()

  @doc "Defines public component option types from conventional declarations."
  defmacro define_component_option_types(definitions) do
    definitions = Macro.expand(definitions, __CALLER__)

    types =
      Enum.map(definitions, fn {type_name, tag} ->
        type = tag |> component!() |> ComponentDocs.option_type_ast()
        builder = type_name |> Atom.to_string() |> String.trim_trailing("_options")

        quote do
          @typedoc "Options accepted by `#{unquote(builder)}/1`."
          @type unquote({type_name, [], []}) :: unquote(type)
        end
      end)

    quote do
      (unquote_splicing(types))
    end
  end
end
