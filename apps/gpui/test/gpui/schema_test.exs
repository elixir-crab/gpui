defmodule GPUI.SchemaTest do
  use ExUnit.Case, async: true

  test "defines the neutral core schema independently" do
    assert GPUI.Schema.tags() == [
             :div,
             :button,
             :layer,
             :span,
             :scroll,
             :list,
             :item,
             :text_surface,
             :text_input,
             :img,
             :text,
             :ui_edge_fade,
             :ui_frost,
             :ui_paint
           ]

    assert :text_surface in GPUI.Schema.identified_tags()
    assert GPUI.Schema.component!(:text_surface).required_events == []
    assert Enum.map(GPUI.Schema.stateful_components(), & &1.kind) == [:text_surface]
    assert :raster in GPUI.Schema.resources()
    assert :border_radius in GPUI.Schema.styles()
    assert :font_weight in GPUI.Schema.styles()
  end

  test "retains neutral defaults and validation" do
    assert %{max_lines: 8, min_lines: 1} = GPUI.Schema.defaults(:text_surface)

    assert_raise ArgumentError, ~r/unknown GPUI component/, fn ->
      GPUI.Schema.component!(:unknown)
    end
  end
end
