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
    assert source =~ "fn normalize(decoded: Decoded) -> NifResult<Config>"
    assert source =~ ~r/decoded\s*\.lifecycle/
    assert source =~ "chrome_content()"
    assert RustQ.valid?(source, "generated_window.rs")
  end
end
