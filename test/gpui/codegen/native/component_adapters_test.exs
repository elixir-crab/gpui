defmodule GPUI.Codegen.Native.ComponentAdaptersTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust

  test "moves each migrated wire field exactly once into owner nodes" do
    source = GPUI.Codegen.Native.ComponentAdapters.items() |> Rust.render_all()

    assert source =~ "style: style_to_core(wire.style)"

    switch = source |> String.split("slider_to_owner", parts: 2) |> hd()

    for field <- ~w(id checked label size disabled loading change)a do
      assert [_one] = Regex.scan(~r/#{field}: wire\.#{field}/, switch)
    end

    assert source =~ "pub(crate) fn switch_to_owner"
    assert source =~ "pub(crate) fn slider_to_owner"
    assert RustQ.valid?(source, "generated_component_adapters.rs")
  end
end
