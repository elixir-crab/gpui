defmodule GPUI.Codegen.Native.TextTypesTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.TextTypes
  alias RustQ.Rust
  alias RustQ.Rust.AST

  test "generates the first renderer-independent text codec slice" do
    items = TextTypes.items()
    source = Rust.render_all(items)

    assert Enum.any?(items, &match?(%AST.Struct{name: :TextPosition}, &1))
    assert Enum.any?(items, &match?(%AST.Struct{name: :TextRange}, &1))
    assert Enum.any?(items, &match?(%AST.Struct{name: :TextSelection}, &1))

    assert source =~ "struct TextPosition"
    assert source =~ "struct TextRange"
    assert source =~ "struct TextSelection"
    assert source =~ "NifMap"
    assert source =~ "utf16_offset: u64"
    assert source =~ "anchor: TextPosition"
    assert RustQ.valid?(source, "generated_text_types.rs")
  end
end
