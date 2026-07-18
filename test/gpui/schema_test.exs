defmodule GPUI.SchemaTest do
  use ExUnit.Case, async: true

  test "defines supported native component schema from one source" do
    assert GPUI.Schema.tags() == [
             :div,
             :button,
             :ui_button,
             :ui_progress,
             :ui_file_picker,
             :ui_copy_button,
             :ui_popover,
             :ui_popover_trigger,
             :ui_popover_content,
             :ui_tooltip,
             :ui_tooltip_trigger,
             :ui_dialog,
             :ui_dialog_trigger,
             :ui_dialog_content,
             :ui_dropdown_menu,
             :ui_dropdown_menu_trigger,
             :ui_dropdown_menu_item,
             :ui_checkbox,
             :ui_input,
             :ui_select,
             :ui_combobox,
             :ui_switch,
             :ui_radio_group,
             :ui_accordion,
             :ui_accordion_item,
             :ui_virtual_list,
             :ui_virtual_list_item,
             :ui_tree,
             :ui_tree_item,
             :ui_tabs,
             :ui_slider,
             :span,
             :scroll,
             :list,
             :item,
             :icon,
             :input,
             :img,
             :text
           ]

    assert :"phx-change" in GPUI.Schema.events()
    assert :"phx-search" in GPUI.Schema.events()
    assert :"phx-release" in GPUI.Schema.events()
    assert :"phx-select" in GPUI.Schema.events()
    assert :"phx-range" in GPUI.Schema.events()
    assert :"phx-toggle" in GPUI.Schema.events()
    assert :ui_progress in GPUI.Schema.identified_tags()
    assert :ui_file_picker in GPUI.Schema.identified_tags()
    assert :ui_copy_button in GPUI.Schema.identified_tags()
    assert :ui_select in GPUI.Schema.identified_tags()
    assert :ui_popover in GPUI.Schema.identified_tags()
    assert :ui_tooltip in GPUI.Schema.identified_tags()
    assert :ui_dialog in GPUI.Schema.identified_tags()
    assert :ui_dropdown_menu in GPUI.Schema.identified_tags()
    assert :ui_virtual_list in GPUI.Schema.identified_tags()
    assert :ui_virtual_list_item in GPUI.Schema.identified_tags()
    assert :ui_tree in GPUI.Schema.identified_tags()
    assert :ui_tree_item in GPUI.Schema.identified_tags()

    assert Enum.map(GPUI.Schema.stateful_components(), & &1.kind) == [
             :popover_component,
             :dialog_component,
             :dropdown_menu_component,
             :input_component,
             :select_component,
             :combobox_component,
             :virtual_list_component,
             :tree_component,
             :slider_component
           ]

    assert :raster in GPUI.Schema.resources()
    assert :border_radius in GPUI.Schema.styles()
    assert :font_weight in GPUI.Schema.styles()
    assert :flex_wrap in GPUI.Schema.styles()
    assert :opacity in GPUI.Schema.styles()
    assert :border_color in GPUI.Schema.styles()
  end
end
