defmodule GPUI.Codegen.Native.ComponentNodesTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust

  test "generates Rustler-independent owner nodes for migrated controls" do
    source = GPUI.Codegen.Native.ComponentNodes.items() |> Rust.render_all()

    assert source =~ "pub struct SwitchNode"
    assert source =~ "pub struct SliderNode"
    assert source =~ "pub change: Option<String>"
    refute source =~ "Term<"
    refute source =~ "NifMap"
    refute source =~ "ResourceArc"
    assert RustQ.valid?(source, "generated_component_nodes.rs")
  end
end
