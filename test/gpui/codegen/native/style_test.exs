defmodule GPUI.Codegen.Native.StyleTest do
  Code.require_file("../../../../codegen/gpui/codegen/native/style.ex", __DIR__)

  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Style
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust
  alias RustQ.Rust.AST
  alias RustQ.Syn

  test "derives StyleAttrs fields from the style schema" do
    style =
      GPUI.Schema.style_specs()
      |> Style.items()
      |> Enum.find(&match?(%AST.Struct{name: :StyleAttrs}, &1))

    assert Enum.map(style.fields, & &1.name) ==
             Enum.map(GPUI.Schema.style_specs(), & &1.field)
  end

  test "generates typed Rusty-Elixir length and default helpers" do
    assert MetaAST.function!(Style, :full_length) |> Rust.render() =~
             "fn full_length() -> gpui::DefiniteLength"

    assert MetaAST.function!(Style, :pixel_length) |> Rust.render() =~
             "gpui::px(value).into()"

    assert MetaAST.function!(Style, :default_style) |> Rust.render() =~
             "StyleAttrs::default()"
  end

  test "keeps one decoding arm for every style contract" do
    source =
      GPUI.Schema.style_specs()
      |> Style.items()
      |> Rust.render_all()

    for spec <- GPUI.Schema.style_specs() do
      assert source =~ "value if value == atoms::#{spec.name}()"
    end

    assert source =~ "_ => false"
    assert RustQ.valid?(source, "generated_style.rs")
    assert Syn.parse!(source) |> Syn.structs() |> Enum.any?(&(&1.name == "StyleAttrs"))
  end
end
