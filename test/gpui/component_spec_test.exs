defmodule GPUI.ComponentSpecTest do
  use ExUnit.Case, async: true

  test "defines supported native component schema from one source" do
    assert GPUI.ComponentSpec.tags() == [:div, :button, :input, :img, :text]
    assert :"phx-change" in GPUI.ComponentSpec.events()
    assert :raster in GPUI.ComponentSpec.resources()
    assert :border_radius in GPUI.ComponentSpec.styles()
  end
end
