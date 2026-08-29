defmodule GPUI.Codegen.Native.ProjectionsTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Projections
  alias RustQ.Rust

  test "owner-local projections are generated together and isolated" do
    vanilla = Projections.schema_items(:vanilla) |> Rust.render_all()
    component = Projections.schema_items(:gpui_component) |> Rust.render_all()

    assert vanilla =~ "EdgeFadeComponentNode"
    refute vanilla =~ "ButtonComponentNode"
    refute vanilla =~ "ui_button"

    assert component =~ "EdgeFadeComponentNode"
    assert component =~ "ButtonComponentNode"
    assert component =~ "ui_button"
  end

  test "vanilla state registry excludes component state" do
    vanilla = Projections.registry_items(:vanilla) |> Rust.render_all()
    component = Projections.registry_items(:gpui_component) |> Rust.render_all()

    refute vanilla =~ "ComponentButton"
    assert component =~ "ComponentDialog"
  end
end
