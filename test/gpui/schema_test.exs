defmodule GPUI.SchemaTest do
  use ExUnit.Case, async: true

  test "defines supported native component schema from one source" do
    assert GPUI.Schema.tags() == [
             :div,
             :button,
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
    assert :raster in GPUI.Schema.resources()
    assert :border_radius in GPUI.Schema.styles()
  end
end
