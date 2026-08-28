defmodule GPUI.Schema.OwnershipTest do
  use ExUnit.Case, async: true

  alias GPUI.Schema.Ownership
  alias GPUI.Schema.Registry

  test "classifies every canonical tag exactly once" do
    assert Enum.map(Ownership.all(), &elem(&1, 0)) == Ownership.tags()
  end

  test "separates declaration provider from native requirement" do
    registry =
      GPUI.Schema.registry()
      |> Registry.include(GPUI.Schema.Surfaces)
      |> Registry.include(GPUI.Components.Schema.Declarations)
      |> Registry.order(Ownership.tags())

    assert Registry.provider!(registry, :div) == GPUI.Schema.Core
    assert Registry.provider!(registry, :ui_button) == GPUI.Components.Schema.Declarations

    assert Ownership.fetch!(:div) == %{category: :primitive, native_requirement: :vanilla}

    assert Ownership.fetch!(:ui_paint) == %{
             category: :specialized_surface,
             native_requirement: :vanilla
           }

    assert Registry.provider!(registry, :ui_paint) == GPUI.Schema.Surfaces

    assert Ownership.fetch!(:ui_button) == %{
             category: :conventional_control,
             native_requirement: :gpui_component
           }
  end
end
