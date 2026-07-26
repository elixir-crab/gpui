defmodule GPUI.Codegen.Native.ResourcesTest do
  Code.require_file("../../../../codegen/gpui/codegen/native/resources.ex", __DIR__)

  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Resources
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust
  alias RustQ.Rust.AST
  alias RustQ.Syn

  test "derives one Rust struct and decoder from every resource schema" do
    items = Resources.items()
    source = Rust.render_all(items)
    parsed = Syn.parse!(source)

    expected_structs =
      GPUI.Schema.resource_specs()
      |> Enum.map(&resource_struct_name(&1.name))
      |> Enum.sort()

    expected_decoders =
      GPUI.Schema.resource_specs()
      |> Enum.map(&decoder_name(&1.name))
      |> Enum.sort()

    assert parsed
           |> Syn.structs()
           |> Enum.map(& &1.name)
           |> Enum.sort() == expected_structs

    assert parsed
           |> Syn.functions()
           |> Enum.map(& &1.name)
           |> Enum.sort() == expected_decoders

    assert RustQ.valid?(source, "generated_resources.rs")
  end

  test "resource field shapes come from schema-backed type declarations" do
    structs =
      Resources.items()
      |> Enum.filter(&match?(%AST.Struct{}, &1))
      |> Map.new(fn struct ->
        {struct.name, Enum.map(struct.fields, & &1.name)}
      end)

    expected =
      Map.new(GPUI.Schema.resource_specs(), fn resource ->
        {String.to_atom(resource_struct_name(resource.name)), Keyword.keys(resource.fields)}
      end)

    assert structs == expected
  end

  test "generated decoders preserve specialized field behavior" do
    raster = MetaAST.function!(Resources, :decode_raster_resource) |> Rust.render()
    resource_ref = MetaAST.function!(Resources, :decode_resource_ref_data) |> Rust.render()

    assert raster =~ "atoms::format()"
    assert raster =~ ~s|"rgba8".to_string()|
    assert raster =~ "decode::<Binary>()"
    assert raster =~ ".as_slice().to_vec()"
    assert raster =~ "decode::<u32>().ok()"

    assert resource_ref =~ "atoms::type_atom()"
    assert resource_ref =~ ".atom_to_string()?"
  end

  defp resource_struct_name(name),
    do: name |> to_string() |> Macro.camelize() |> Kernel.<>("Data")

  defp decoder_name(:resource_ref), do: "decode_resource_ref_data"
  defp decoder_name(name), do: "decode_#{name}_resource"
end
