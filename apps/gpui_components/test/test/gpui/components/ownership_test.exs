defmodule GPUI.Components.SchemaIsolationTest do
  use ExUnit.Case, async: true

  alias GPUI.Schema.Registry

  test "provider identity follows explicit composition without a global tag manifest" do
    registry =
      GPUI.Schema.registry()
      |> Registry.include(GPUI.Schema.Surfaces)
      |> Registry.include(GPUI.Components.Schema.Declarations)

    assert Registry.provider!(registry, :div) == GPUI.Schema.Core
    assert Registry.provider!(registry, :ui_paint) == GPUI.Schema.Surfaces
    assert Registry.provider!(registry, :ui_button) == GPUI.Components.Schema.Declarations
  end

  test "provider composition has deterministic provider-local order" do
    registry =
      GPUI.Schema.registry()
      |> Registry.include(GPUI.Schema.Surfaces)
      |> Registry.include(GPUI.Components.Schema.Declarations)

    expected =
      GPUI.Schema.Core.components() ++
        GPUI.Schema.Surfaces.components() ++ GPUI.Components.Schema.Declarations.components()

    assert Registry.components(registry) == expected
  end
end
