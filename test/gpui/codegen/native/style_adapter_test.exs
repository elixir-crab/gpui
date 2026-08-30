defmodule GPUI.Codegen.Native.StyleAdapterTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust

  test "converts every schema-owned style field exactly once" do
    source = GPUI.Codegen.Native.StyleAdapter.items() |> Rust.render_all()

    for spec <- GPUI.Schema.style_specs() do
      assert length(Regex.scan(~r/style\.#{spec.field} = wire\.#{spec.field}/, source)) == 1
    end

    assert source =~ "gpui_core::style_wire::length"
    assert source =~ "gpui_core::style_wire::definite_length"
    assert RustQ.valid?(source, "generated_style_adapter.rs")
  end
end
