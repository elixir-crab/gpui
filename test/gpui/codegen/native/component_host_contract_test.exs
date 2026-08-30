defmodule GPUI.Codegen.Native.ComponentHostContractTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust

  test "generates component event variants from the inspectable Elixir contract" do
    source = GPUI.Codegen.Native.ComponentHostContract.items() |> Rust.render_all()

    for event <- GPUI.Components.NativeContract.events() do
      assert source =~ Macro.camelize(Atom.to_string(event.name))
    end

    assert RustQ.valid?(source, "generated_component_host_contract.rs")
  end
end
