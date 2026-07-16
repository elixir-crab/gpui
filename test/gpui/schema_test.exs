defmodule GPUI.SchemaTest do
  use ExUnit.Case, async: true

  test "defines supported native component schema from one source" do
    assert GPUI.Schema.tags() == [
             :div,
             :button,
             :ui_button,
             :ui_checkbox,
             :ui_input,
             :ui_select,
             :ui_combobox,
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
    assert :ui_select in GPUI.Schema.identified_tags()
    assert :raster in GPUI.Schema.resources()
    assert :border_radius in GPUI.Schema.styles()
    assert :font_weight in GPUI.Schema.styles()
    assert :flex_wrap in GPUI.Schema.styles()
    assert :opacity in GPUI.Schema.styles()
    assert :border_color in GPUI.Schema.styles()
  end
end
