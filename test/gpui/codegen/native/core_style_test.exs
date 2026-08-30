defmodule GPUI.Codegen.Native.CoreStyleTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust

  test "generates every Elixir-owned style field without boundary types" do
    source = GPUI.Codegen.Native.CoreStyle.items() |> Rust.render_all()

    for spec <- GPUI.Schema.style_specs() do
      assert source =~ "pub #{spec.field}:"
    end

    assert source =~ "pub enum Length"
    assert source =~ "pub struct Style"
    refute source =~ "Term<"
    refute source =~ "NifMap"
    refute source =~ "NifResult"
    refute source =~ "gpui::"
    assert RustQ.valid?(source, "generated_core_style.rs")
  end
end
