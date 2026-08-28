defmodule GPUI.Components.Schema do
  @moduledoc """
  Conventional component declarations owned by the `gpui_components` package.

  The current native protocol remains coordinated with `GPUI.Schema` while the
  declarations migrate package by package. This module is the stable schema
  owner consumed by component builders and explicit host composition.
  """

  @behaviour GPUI.Schema.Provider

  alias GPUI.Schema.ComponentDocs

  @component_tags ~w(
    ui_drop_target ui_split ui_button ui_progress
    ui_popover ui_popover_trigger ui_popover_content ui_tooltip ui_tooltip_trigger
    ui_dialog ui_dialog_trigger ui_dialog_content ui_dropdown_menu
    ui_dropdown_menu_trigger ui_dropdown_menu_item ui_checkbox ui_input ui_select
    ui_combobox ui_switch ui_radio_group ui_accordion ui_accordion_item
    ui_virtual_list ui_virtual_list_item ui_virtual_collection ui_virtual_item
    ui_rich_text ui_data_table ui_table_column ui_table_row ui_tree ui_tree_item
    ui_code_viewer ui_code_line ui_tabs ui_slider
  )a

  @components Enum.map(@component_tags, &GPUI.Schema.component!/1)

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
    component!(tag)
    GPUI.Schema.validate_component_assigns!(assigns, tag, extra_attrs)
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
