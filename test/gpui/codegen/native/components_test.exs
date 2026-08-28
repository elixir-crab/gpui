defmodule GPUI.Codegen.Native.ComponentDefinitionsTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.ComponentDefinitions
  alias RustQ.Rust
  alias RustQ.Rust.AST
  alias RustQ.Syn

  test "derives one struct and decoder for every native component contract" do
    components = component_contracts()
    items = ComponentDefinitions.items()

    structs = Enum.filter(items, &match?(%AST.Struct{}, &1))
    functions = Enum.filter(items, &match?(%AST.Function{}, &1))

    assert Enum.map(structs, & &1.name) == Enum.map(components, &node_name/1)
    assert Enum.map(functions, & &1.name) == Enum.map(components, &decoder_name/1)
  end

  test "component struct fields follow schema attributes, children, and events" do
    structs =
      ComponentDefinitions.items()
      |> Enum.filter(&match?(%AST.Struct{}, &1))
      |> Map.new(&{&1.name, Enum.map(&1.fields, fn field -> field.name end)})

    for component <- component_contracts() do
      expected =
        [:style] ++
          Keyword.keys(component.attrs) ++
          if(component.children, do: [:children], else: []) ++
          Keyword.keys(component.events)

      assert structs[node_name(component)] == expected
    end
  end

  test "generated component Rust is structurally valid" do
    source = ComponentDefinitions.items() |> Rust.render_all()
    parsed = Syn.parse!(source)

    assert length(Syn.structs(parsed)) == length(component_contracts())
    assert length(Syn.functions(parsed)) == length(component_contracts())
    assert RustQ.valid?(source, "generated_components.rs")
  end

  defp component_contracts do
    GPUI.Codegen.Native.Host.components()
    |> Enum.filter(&String.ends_with?(Atom.to_string(&1.kind), "_component"))
  end

  defp node_name(component),
    do:
      component.kind
      |> Atom.to_string()
      |> Macro.camelize()
      |> Kernel.<>("Node")
      |> String.to_atom()

  defp decoder_name(component), do: String.to_atom("decode_generated_#{component.kind}")
end
