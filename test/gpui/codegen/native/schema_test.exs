defmodule GPUI.Codegen.Native.SchemaTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Schema
  alias RustQ.Rust
  alias RustQ.Syn

  test "composes a deterministic, structurally valid native schema" do
    items = Schema.items()
    source = Rust.render_all(items)
    parsed = Syn.parse!(source)

    assert source == Rust.render_all(Schema.items())
    assert RustQ.valid?(source, "generated_native_schema.rs")

    assert Enum.any?(Syn.enums(parsed), &(&1.name == "GeneratedComponentKind"))
    assert Enum.any?(Syn.enums(parsed), &(&1.name == "GeneratedElementTag"))
    assert Enum.any?(Syn.enums(parsed), &(&1.name == "ElementNode"))
    assert Enum.any?(Syn.enums(parsed), &(&1.name == "AccessibilityRole"))
    assert Enum.any?(Syn.enums(parsed), &(&1.name == "AccessibilityChecked"))
    assert Enum.any?(Syn.enums(parsed), &(&1.name == "AccessibilityOrientation"))
    assert Enum.any?(Syn.structs(parsed), &(&1.name == "AccessibilitySemantics"))
    assert Enum.any?(Syn.structs(parsed), &(&1.name == "StyleAttrs"))
    assert Enum.any?(Syn.functions(parsed), &(&1.name == "render_generated_component_node"))

    assert_unique_named_items(parsed)
    assert source =~ "accessibility: AccessibilitySemantics"
    assert source =~ "impl AccessibilityRole"
    assert source =~ "fn gpui_role(&self) -> gpui::Role"
    assert source =~ "fn toggled(&self) -> gpui::Toggled"
    assert source =~ "fn gpui_orientation(&self) -> gpui::Orientation"
    refute source =~ "accessibility_role: Option<String>"
    refute source =~ ".then("
  end

  test "composes a deterministic, structurally valid component registry" do
    items = Schema.registry_items()
    source = Rust.render_all(items)
    parsed = Syn.parse!(source)

    assert source == Rust.render_all(Schema.registry_items())
    assert RustQ.valid?(source, "generated_component_registry.rs")

    assert Enum.any?(Syn.enums(parsed), &(&1.name == "ComponentKind"))
    assert Enum.any?(Syn.enums(parsed), &(&1.name == "StatefulComponent"))
    assert [%{target: "ComponentRegistry"}] = Syn.impls(parsed)

    assert_unique_named_items(parsed)
  end

  defp assert_unique_named_items(parsed) do
    names =
      Enum.map(Syn.enums(parsed), &{:enum, &1.name}) ++
        Enum.map(Syn.structs(parsed), &{:struct, &1.name}) ++
        Enum.map(Syn.type_aliases(parsed), &{:type, &1.name}) ++
        Enum.map(Syn.statics(parsed), &{:static, &1.name}) ++
        Enum.map(Syn.functions(parsed), &{:function, &1.name})

    assert Enum.uniq(names) == names
  end
end
