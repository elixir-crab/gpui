defmodule GPUI.SchemaTest do
  use ExUnit.Case, async: true

  test "defines supported native component schema from one source" do
    assert GPUI.Schema.tags() == [
             :div,
             :button,
             :layer,
             :ui_drop_target,
             :ui_split,
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
             :ui_virtual_collection,
             :ui_virtual_item,
             :ui_rich_text,
             :ui_data_table,
             :ui_table_column,
             :ui_table_row,
             :ui_tree,
             :ui_tree_item,
             :ui_code_viewer,
             :ui_code_line,
             :ui_tabs,
             :ui_slider,
             :span,
             :scroll,
             :list,
             :item,
             :icon,
             :text_surface,
             :input,
             :img,
             :text
           ]

    assert :"phx-change" in GPUI.Schema.events()
    assert :"phx-search" in GPUI.Schema.events()
    assert :"phx-release" in GPUI.Schema.events()
    assert :"phx-select" in GPUI.Schema.events()
    assert :"phx-link" in GPUI.Schema.events()
    assert :"phx-range" in GPUI.Schema.events()
    assert :"phx-toggle" in GPUI.Schema.events()
    assert :"phx-copy" in GPUI.Schema.events()
    assert :"phx-transaction" in GPUI.Schema.events()
    assert :"phx-selection-change" in GPUI.Schema.events()
    assert :"phx-viewport-change" in GPUI.Schema.events()
    assert :"phx-geometry-change" in GPUI.Schema.events()
    assert :"phx-range-geometry-change" in GPUI.Schema.events()
    assert :"phx-hit-test" in GPUI.Schema.events()
    assert :"phx-bounds-change" in GPUI.Schema.events()
    assert :"phx-focus" in GPUI.Schema.events()
    assert :"phx-blur" in GPUI.Schema.events()
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
    assert :ui_virtual_collection in GPUI.Schema.identified_tags()
    assert :ui_virtual_item in GPUI.Schema.identified_tags()
    assert :ui_rich_text in GPUI.Schema.identified_tags()
    assert :ui_tree in GPUI.Schema.identified_tags()
    assert :ui_tree_item in GPUI.Schema.identified_tags()
    assert :ui_code_viewer in GPUI.Schema.identified_tags()
    assert :ui_code_line in GPUI.Schema.identified_tags()
    assert :text_surface in GPUI.Schema.identified_tags()

    assert GPUI.Schema.component!(:ui_input).required_events == [:"phx-change"]
    assert GPUI.Schema.component!(:ui_slider).required_events == [:"phx-change"]
    assert GPUI.Schema.component!(:text_surface).required_events == []

    assert Enum.map(GPUI.Schema.stateful_components(), & &1.kind) == [
             :split_component,
             :popover_component,
             :dialog_component,
             :dropdown_menu_component,
             :input_component,
             :select_component,
             :combobox_component,
             :virtual_list_component,
             :virtual_collection_component,
             :rich_text_component,
             :data_table_component,
             :tree_component,
             :code_viewer_component,
             :slider_component,
             :text_surface
           ]

    assert :raster in GPUI.Schema.resources()
    assert :border_radius in GPUI.Schema.styles()
    assert :font_weight in GPUI.Schema.styles()
    assert :flex_wrap in GPUI.Schema.styles()
    assert :opacity in GPUI.Schema.styles()
    assert :border_color in GPUI.Schema.styles()
    assert :flex_basis in GPUI.Schema.styles()
    assert :overflow in GPUI.Schema.styles()
    assert :white_space in GPUI.Schema.styles()
    assert :text_overflow in GPUI.Schema.styles()
    assert :text_align in GPUI.Schema.styles()
    assert :truncate in GPUI.Schema.styles()
    assert :cursor in GPUI.Schema.styles()
  end

  test "derives public option documentation from component contracts" do
    slider_doc = GPUI.Schema.component_options_doc(:ui_slider)

    assert slider_doc =~ "## Options"
    assert slider_doc =~ "| `:label` | non-empty `String.t()` | yes | — |"

    assert slider_doc =~
             "| `:orientation` | `\"horizontal\"`, `\"vertical\"` | no | `\"horizontal\"` |"

    assert slider_doc =~ "| `:\"phx-change\"` | non-empty event name | yes | — |"

    tooltip_doc = GPUI.Schema.component_options_doc(:ui_tooltip)
    assert tooltip_doc =~ "| `:trigger` | one named slot | yes | — |"
    assert tooltip_doc =~ "| `:content` | one named slot | yes | — |"
    refute tooltip_doc =~ "`:text`"
    refute tooltip_doc =~ "`:children`"
  end

  test "publishes generated option types and tables for every public builder" do
    ui_builders = [
      :button,
      :progress,
      :file_picker,
      :copy_button,
      :checkbox,
      :input,
      :select,
      :combobox,
      :switch,
      :radio_group,
      :accordion,
      :accordion_item,
      :virtual_list,
      :virtual_list_item,
      :virtual_collection,
      :virtual_item,
      :rich_text,
      :data_table,
      :table_column,
      :table_row,
      :tree,
      :tree_item,
      :code_viewer,
      :code_line,
      :tabs,
      :slider
    ]

    overlay_builders = [:tooltip, :dialog, :dropdown_menu, :popover]

    assert_options_docs(GPUI.UI, ui_builders)
    assert_options_docs(GPUI.UI.Overlay, overlay_builders)
    assert_option_types(GPUI.UI, ui_builders)
    assert_option_types(GPUI.UI.Overlay, overlay_builders)
  end

  test "projects component defaults for public builders and native decoders" do
    assert %{
             max_bytes: 26_214_400,
             disabled: false
           } = GPUI.Schema.defaults(:ui_file_picker)

    assert %{
             item_height: 40.0,
             reveal_strategy: "nearest",
             total_count: 0,
             offset: 0,
             overscan: 8,
             disabled: false
           } = GPUI.Schema.defaults(:ui_tree)

    assert %{
             mode: "plain",
             max_columns: 0,
             tab_width: 4,
             show_line_numbers: true
           } = GPUI.Schema.defaults(:ui_code_viewer)

    assert %{max: 250.0, value: 10.0} =
             GPUI.Schema.apply_defaults(%{max: 250.0, value: 10.0}, :ui_progress)

    assert_raise ArgumentError, ~r/unknown GPUI component/, fn ->
      GPUI.Schema.component!(:unknown)
    end
  end

  defp assert_options_docs(module, functions) do
    {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(module)

    function_docs =
      Map.new(docs, fn
        {{:function, name, 1}, _, _, %{"en" => doc}, _} -> {name, doc}
        {{_kind, name, _arity}, _, _, _, _} -> {name, ""}
      end)

    Enum.each(functions, fn function ->
      assert function_docs[function] =~ "## Options",
             "expected #{inspect(module)}.#{function}/1 to contain a generated options table"
    end)
  end

  defp assert_option_types(module, functions) do
    {:ok, types} = Code.Typespec.fetch_types(module)
    names = Enum.map(types, fn {_visibility, {name, _type, args}} -> {name, length(args)} end)

    Enum.each(functions, fn function ->
      type_name = String.to_atom("#{function}_options")

      assert {type_name, 0} in names,
             "expected #{inspect(module)} to publish #{type_name}/0"
    end)
  end
end
