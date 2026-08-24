defmodule GPUI.Codegen.Native.ExtensionsTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Extensions
  alias RustQ.Rust

  test "generates exact versions and closed capability vocabularies" do
    source = Extensions.items() |> Rust.render_all()

    assert source =~ "const EDGE_FADE_EXTENSION_VERSION: u32 = 1;"
    assert source =~ "const FROST_EXTENSION_VERSION: u32 = 1;"
    assert source =~ "const PAINT_EXTENSION_VERSION: u32 = 1;"
    assert source =~ ~s("reduced_transparency")
    refute source =~ ~s("backdrop_blur")
    assert source =~ ~s("rect")
    assert source =~ ~s("line")
    assert RustQ.valid?(source, "generated_extensions.rs")
  end
end
