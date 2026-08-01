defmodule GPUI.Codegen.Native.StyleTest do
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

    assert MetaAST.function!(Style, :fraction_length) |> Rust.render() =~
             "gpui::relative(value)"

    assert MetaAST.function!(Style, :pixel_length) |> Rust.render() =~
             "gpui::px(value).into()"

    assert MetaAST.function!(Style, :auto_flex_basis) |> Rust.render() =~
             "gpui::Length::Auto"

    assert MetaAST.function!(Style, :default_style) |> Rust.render() =~
             "StyleAttrs::default()"
  end

  test "generates rendering for every rendered style contract" do
    source =
      GPUI.Schema.style_specs()
      |> Style.items()
      |> Rust.render_all()

    for spec <- Enum.reject(GPUI.Schema.style_specs(), &is_nil(&1.render)) do
      assert source =~ "style.#{spec.field}"
    end

    assert source =~ "fn apply_generated_render_styles"
    assert source =~ "element = element.flex();"
    assert source =~ "gpui::FontWeight::BOLD"
    assert source =~ "element = element.border_color(gpui::rgb(value));"
    assert source =~ "element = element.flex_basis(value);"
    assert source =~ "element = element.truncate();"
    assert source =~ "element = element.cursor_pointer();"
    assert source =~ "element = element.relative();"
    assert source =~ "element = element.absolute();"
    assert source =~ "element = element.top(value);"
    assert source =~ "element = element.right(value);"
    assert source =~ "element = element.bottom(value);"
    assert source =~ "element = element.left(value);"
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
