defmodule GPUI.Components.SchemaTest do
  use ExUnit.Case, async: true

  alias GPUI.Components.Schema
  alias GPUI.Schema.Registry

  test "owns conventional component declarations" do
    assert length(Schema.components()) > 0
    assert Enum.all?(Schema.components(), &String.starts_with?(Atom.to_string(&1.tag), "ui_"))
    assert Schema.component!(:ui_button).kind == :button_component
  end

  test "composes explicitly with the neutral core schema" do
    vanilla = GPUI.Schema.registry()
    composed = Registry.include(vanilla, Schema)

    assert :div in Registry.native_tags(composed)
    assert :ui_button in Registry.native_tags(composed)
    assert Registry.component!(composed, :ui_button).kind == :button_component
  end
end
