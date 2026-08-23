defmodule GPUI.Codegen.Native.EventBoundaryTest do
  use RustQ.Test, async: true

  alias GPUI.Codegen.Native.EventBoundary
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  test "generates event request codecs and public wrappers" do
    source = rust_source!(EventBoundary)

    assert %AST.Struct{name: :InjectRequest} =
             MetaAST.type_item!(EventBoundary, :InjectRequest)

    assert %AST.Enum{name: :InjectKind} = MetaAST.type_item!(EventBoundary, :InjectKind)
    assert nif_exported?(EventBoundary, :drain_events, 1)
    assert nif_exported?(EventBoundary, :inject_event, 2)
    assert source =~ "drain_events_impl(env, runtime)"
    assert source =~ "inject_event_impl(env, runtime, inject_request(event))"
  end

  test "derives a closed injected event kind decoder" do
    source = rust_source!(EventBoundary)

    for kind <- ~w(
          window_close_request window_focus window_blur window_closed
          click command change release search submit keydown keyup
        ) do
      assert source =~ Macro.camelize(kind)
    end

    assert source =~ "event.map_get(atoms::type_atom())?.decode::<InjectKind>()?"
    assert source =~ "decode_event_value(value)"
    assert RustQ.valid?(source, "generated_event_boundary.rs")
  end
end
