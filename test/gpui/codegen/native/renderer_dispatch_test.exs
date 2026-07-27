defmodule GPUI.Codegen.Native.RendererDispatchTest do
  Code.require_file("../../../../codegen/gpui/codegen/native/renderers.ex", __DIR__)
  Code.require_file("../../../../codegen/gpui/codegen/native/renderer_dispatch.ex", __DIR__)

  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.RendererDispatch
  alias GPUI.Codegen.Native.Renderers
  alias RustQ.Rust
  alias RustQ.Syn

  test "derives one renderer arm for every component contract" do
    source = RendererDispatch.item() |> Rust.render()

    components = component_contracts()
    nodes = Enum.map(components, &node_name/1)
    renderers = Renderers.for_nodes!(nodes)

    for component <- components do
      renderer = Map.fetch!(renderers, node_name(component))
      assert source =~ "ElementNode::#{variant(component.kind)}(node)"
      assert source =~ Enum.map_join(renderer.path, "::", &to_string/1)
    end

    assert source =~ "_ => unreachable!()"
  end

  test "preserves renderer argument contracts discovered from Rust source" do
    source = RendererDispatch.item() |> Rust.render()

    assert source =~ "render_input_component(element_id, node, context)"
    assert source =~ "render_button_component(node, context)"
    assert source =~ "context: &mut element::ElementRenderContext<'_, '_>"
  end

  test "generated renderer dispatch Rust is structurally valid" do
    source = RendererDispatch.item() |> Rust.render()
    assert [%{name: "render_generated_component_node"}] = Syn.functions(Syn.parse!(source))
    assert RustQ.valid?(source, "generated_renderer_dispatch.rs")
  end

  defp component_contracts do
    GPUI.Schema.components()
    |> Enum.filter(&String.ends_with?(Atom.to_string(&1.kind), "_component"))
  end

  defp node_name(component),
    do:
      component.kind
      |> Atom.to_string()
      |> Macro.camelize()
      |> Kernel.<>("Node")
      |> String.to_atom()

  defp variant(value), do: value |> Atom.to_string() |> Macro.camelize()
end
