defmodule GPUI.Codegen.Native.WindowTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Window
  alias RustQ.Rust
  alias RustQ.Rust.AST

  test "derives the native window payload and normalization from one typed contract" do
    items = RustQ.Native.items(Window)
    source = Rust.render_all(items)

    assert Enum.any?(items, &match?(%AST.Struct{name: :Decoded}, &1))
    assert Enum.any?(items, &match?(%AST.Struct{name: :Config}, &1))
    assert source =~ "#[derive(Clone, Debug, rustler::NifMap)]"
    assert source =~ ~r/fn normalize<'a>\(decoded: Decoded<'a>\) -> NifResult<Config<'a>>/
    assert source =~ "pub root: Root<'a>"
    assert source =~ "pub tree: Term<'a>"
    assert source =~ ~r/tree: decoded\s*\.root\s*\.tree/
    assert source =~ ~r/decoded\s*\.lifecycle/
    assert source =~ "chrome_content()"
    refute source =~ "fn window_tree"
    assert RustQ.valid?(source, "generated_window.rs")
  end

  test "keeps malformed tree rejection in the generated element decoder" do
    window_source = Window |> RustQ.Native.items() |> Rust.render_all()
    element_source = GPUI.Codegen.Native.Schema.items() |> Rust.render_all()

    assert window_source =~ "pub root: Root<'a>"
    assert window_source =~ "pub tree: Term<'a>"
    assert element_source =~ "fn decode_element_node"
    refute window_source =~ "fn decode_element_node"
    refute element_source =~ "fn window_tree"
  end
end
