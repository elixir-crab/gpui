defmodule GPUI.Codegen.Native.SchemaTypesTest do
  Code.require_file("../../../../codegen/gpui/codegen/native/schema_types.ex", __DIR__)

  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.SchemaTypes
  alias RustQ.Rust
  alias RustQ.Syn

  test "derives component kind and element tag variants from schema" do
    component_kind = SchemaTypes.component_kind_item()
    element_tag = SchemaTypes.element_tag_item()

    expected_kinds =
      GPUI.Schema.components()
      |> Enum.map(& &1.kind)
      |> Enum.uniq()
      |> Kernel.++([:unknown])
      |> Enum.map(&variant/1)

    expected_tags = GPUI.Schema.native_tags() |> Kernel.++([:unknown]) |> Enum.map(&variant/1)

    assert Enum.map(component_kind.variants, & &1.name) == expected_kinds
    assert Enum.map(element_tag.variants, & &1.name) == expected_tags
  end

  test "derives ElementNode payload variants from component contracts" do
    element_node = SchemaTypes.element_node_item()

    expected =
      [:Viewport, :Div, :Input] ++
        (GPUI.Schema.components()
         |> Enum.filter(&String.ends_with?(Atom.to_string(&1.kind), "_component"))
         |> Enum.map(&variant(&1.kind))) ++
        [:Image, :Text]

    assert Enum.map(element_node.variants, & &1.name) == expected
  end

  test "generated schema type Rust is structurally valid" do
    source =
      [
        SchemaTypes.component_kind_item(),
        SchemaTypes.element_tag_item(),
        SchemaTypes.element_node_item()
      ]
      |> Rust.render_all()

    assert [_component_kind, _element_tag, _element_node] = Syn.enums(Syn.parse!(source))
    assert RustQ.valid?(source, "generated_schema_types.rs")
  end

  defp variant(value), do: value |> Atom.to_string() |> Macro.camelize() |> String.to_atom()
end
