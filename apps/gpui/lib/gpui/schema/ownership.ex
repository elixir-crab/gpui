defmodule GPUI.Schema.Ownership do
  @moduledoc """
  Closed classification audit for the current canonical protocol tags.

  Provider identity comes from `GPUI.Schema.Registry`, not package names. This
  audit records only renderer-independent category and native capability facts.
  It remains closed so adding a canonical wire tag requires an explicit review.
  """

  @type category :: :primitive | :specialized_surface | :conventional_control | :renderer_internal
  @type native_requirement :: :vanilla | :gpui_component

  @primitive ~w(div button layer span scroll list item text_surface text_input img text)a
  @specialized_surface ~w(ui_edge_fade ui_frost ui_paint)a
  @component_specialized_surface [:ui_drop_target]

  @conventional_control ~w(
    ui_split ui_button ui_progress ui_popover ui_popover_trigger ui_popover_content
    ui_tooltip ui_tooltip_trigger ui_dialog ui_dialog_trigger ui_dialog_content
    ui_dropdown_menu ui_dropdown_menu_trigger ui_dropdown_menu_item ui_checkbox
    ui_input ui_select ui_combobox ui_switch ui_radio_group ui_accordion
    ui_accordion_item ui_virtual_list ui_virtual_list_item ui_virtual_collection
    ui_virtual_item ui_rich_text ui_data_table ui_table_column ui_table_row ui_tree
    ui_tree_item ui_code_viewer ui_code_line ui_tabs ui_slider
  )a

  @renderer_internal [:viewport]

  @manifest Enum.concat([
              Enum.map(
                @renderer_internal,
                &{&1, %{category: :renderer_internal, native_requirement: :vanilla}}
              ),
              Enum.map(
                @primitive,
                &{&1, %{category: :primitive, native_requirement: :vanilla}}
              ),
              Enum.map(
                @specialized_surface,
                &{&1, %{category: :specialized_surface, native_requirement: :vanilla}}
              ),
              Enum.map(
                @component_specialized_surface,
                &{&1, %{category: :specialized_surface, native_requirement: :gpui_component}}
              ),
              Enum.map(
                @conventional_control,
                &{&1, %{category: :conventional_control, native_requirement: :gpui_component}}
              )
            ])

  @by_tag Map.new(@manifest)

  if map_size(@by_tag) != length(@manifest) do
    raise ArgumentError, "schema ownership tags must be unique"
  end

  @canonical_tags ~w(
    viewport div button layer ui_drop_target ui_split ui_button ui_edge_fade ui_frost ui_paint
    ui_progress ui_popover ui_popover_trigger ui_popover_content ui_tooltip ui_tooltip_trigger
    ui_dialog ui_dialog_trigger ui_dialog_content ui_dropdown_menu ui_dropdown_menu_trigger
    ui_dropdown_menu_item ui_checkbox ui_input ui_select ui_combobox ui_switch ui_radio_group
    ui_accordion ui_accordion_item ui_virtual_list ui_virtual_list_item ui_virtual_collection
    ui_virtual_item ui_rich_text ui_data_table ui_table_column ui_table_row ui_tree ui_tree_item
    ui_code_viewer ui_code_line ui_tabs ui_slider span scroll list item text_surface text_input img text
  )a

  @doc "Returns every audited canonical tag in protocol order."
  @spec tags() :: [atom()]
  def tags, do: @canonical_tags

  @doc "Returns the closed classification in canonical protocol order."
  @spec all() :: [{atom(), %{category: category(), native_requirement: native_requirement()}}]
  def all, do: Enum.map(@canonical_tags, &{&1, fetch!(&1)})

  @doc "Returns classification metadata for one canonical tag."
  @spec fetch!(atom()) :: %{category: category(), native_requirement: native_requirement()}
  def fetch!(tag) when is_atom(tag), do: Map.fetch!(@by_tag, tag)

  @doc "Returns canonical tags requiring one statically linked native capability."
  @spec tags_for_requirement(native_requirement()) :: [atom()]
  def tags_for_requirement(requirement) when requirement in [:vanilla, :gpui_component] do
    for {tag, %{native_requirement: ^requirement}} <- all(), do: tag
  end
end
