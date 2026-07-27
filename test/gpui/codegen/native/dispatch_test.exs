defmodule GPUI.Codegen.Native.DispatchTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Dispatch
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust
  alias RustQ.Syn

  test "derives tag and component kind dispatch from schema" do
    tag_source = MetaAST.function!(Dispatch, :decode_generated_element_tag) |> Rust.render()
    kind_source = MetaAST.function!(Dispatch, :generated_component_kind) |> Rust.render()

    for component <- GPUI.Schema.components() do
      assert tag_source =~
               ~s|"#{component.tag}" => GeneratedElementTag::#{variant(component.tag)}|

      assert kind_source =~ "GeneratedElementTag::#{variant(component.tag)}"
      assert kind_source =~ "GeneratedComponentKind::#{variant(component.kind)}"
    end

    assert tag_source =~ "_ => GeneratedElementTag::Unknown"
    assert kind_source =~ "GeneratedElementTag::Unknown => GeneratedComponentKind::Unknown"
  end

  test "derives element decoder dispatch from component contracts" do
    source = MetaAST.function!(Dispatch, :decode_generated_element_node) |> Rust.render()

    for component <- GPUI.Schema.components() |> Enum.uniq_by(& &1.kind) do
      assert source =~ "GeneratedComponentKind::#{variant(component.kind)} =>"
    end

    assert source =~ "GeneratedComponentKind::Unknown => Err(rustler::Error::BadArg)"
  end

  test "generated dispatch Rust is structurally valid" do
    source = Dispatch.items() |> Rust.render_all()
    assert [_first, _second, _third] = Syn.functions(Syn.parse!(source))
    assert RustQ.valid?(source, "generated_dispatch.rs")
  end

  defp variant(value), do: value |> Atom.to_string() |> Macro.camelize()
end
