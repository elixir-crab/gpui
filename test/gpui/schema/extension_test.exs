defmodule GPUI.Schema.ExtensionTest do
  use ExUnit.Case, async: true

  alias GPUI.Schema.Extension

  test "exposes versioned presentation contracts from the canonical component schema" do
    assert [
             %Extension{id: :edge_fade, version: 1},
             %Extension{id: :frost, version: 1},
             %Extension{id: :paint, version: 1}
           ] = GPUI.Schema.extensions()

    assert %Extension{
             id: :frost,
             version: 1,
             capabilities: capabilities
           } = GPUI.Schema.extension(:frost)

    assert capabilities == [
             :solid_fallback,
             :translucent_fallback,
             :reduced_transparency,
             :backdrop_blur
           ]

    assert_raise ArgumentError, ~r/unknown GPUI extension/, fn ->
      GPUI.Schema.extension(:native_widget)
    end
  end
end
