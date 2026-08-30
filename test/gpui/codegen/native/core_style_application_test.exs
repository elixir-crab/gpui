defmodule GPUI.Codegen.Native.CoreStyleApplicationTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust

  test "generates complete core style application from render declarations" do
    source = GPUI.Codegen.Native.CoreStyleApplication.items() |> Rust.render_all()

    for %{field: field, render: render} <- GPUI.Schema.style_specs(), not is_nil(render) do
      assert source =~ "style.#{field}"
    end

    assert source =~ "pub fn apply"
    assert RustQ.valid?(source, "generated_core_style_application.rs")
  end
end
