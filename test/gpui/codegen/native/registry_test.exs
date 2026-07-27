defmodule GPUI.Codegen.Native.RegistryTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Registry
  alias RustQ.Rust
  alias RustQ.Rust.AST
  alias RustQ.Syn

  test "derives registry enums and methods from stateful components" do
    [kind, state, %AST.Impl{items: methods}] = Registry.items()
    components = GPUI.Schema.stateful_components()

    assert Enum.map(kind.variants, & &1.name) == Enum.map(components, &variant/1)
    assert Enum.map(state.variants, & &1.name) == Enum.map(components, &variant/1)

    assert Enum.map(methods, & &1.name) ==
             Enum.flat_map(components, fn component ->
               method = registry_method(component)
               [String.to_atom("#{method}_mut"), String.to_atom("insert_#{method}")]
             end)
  end

  test "getters and inserters preserve registry behavior" do
    source = Registry.items() |> Enum.map_join("\n", &Rust.render/1)

    for component <- GPUI.Schema.stateful_components() do
      method = registry_method(component)
      variant = variant(component)
      type = String.to_atom("Component#{variant}")

      assert source =~ "fn #{method}_mut("
      assert source =~ "Option<&mut #{type}>"
      assert source =~ "ComponentKey::new(ComponentKind::#{variant}, id)"
      assert source =~ "Some(StatefulComponent::#{variant}(component)) => Some(component)"
      assert source =~ "fn insert_#{method}("
      assert source =~ "component: #{type}"
      assert source =~ "StatefulComponent::#{variant}(component)"
    end
  end

  test "generated registry Rust is structurally valid" do
    source = Registry.items() |> Enum.map_join("\n", &Rust.render/1)

    assert ["ComponentKind", "StatefulComponent"] ==
             source |> Syn.parse!() |> Syn.enums() |> Enum.map(& &1.name)

    assert RustQ.valid?(source, "generated_component_registry.rs")
  end

  defp registry_method(component),
    do: component.kind |> Atom.to_string() |> String.replace_suffix("_component", "")

  defp variant(component),
    do: component |> registry_method() |> Macro.camelize() |> String.to_atom()
end
