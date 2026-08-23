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

  test "generates encoders for simple routed and lifecycle events" do
    source = GPUI.Codegen.Native.Events.items() |> RustQ.Rust.render_all()

    assert source =~ "fn encode_bounds_event"
    assert source =~ "fn encode_focus_event"
    assert source =~ "fn encode_missing_resource_event"
    assert source =~ "fn encode_clipboard_event"
    assert source =~ "fn encode_transfer_event"
    assert source =~ "fn encode_virtual_range_event"
    assert source =~ "fn encode_file_dialog_event"
    assert source =~ "fn encode_file_dialog_selected"
    assert source =~ "fn encode_file_dialog_cancelled"
    assert source =~ "fn encode_file_dialog_error"
    assert source =~ "fn encode_revisioned_selection_event"
    assert source =~ "fn encode_revisioned_viewport_event"
    assert source =~ "fn encode_revisioned_geometry_event"
    assert source =~ "fn encode_revisioned_range_geometry_event"
    assert source =~ "fn encode_revisioned_position_event"
    assert source =~ "fn encode_revisioned_event"
    assert source =~ "atoms::revision()"
    assert source =~ "fn encode_named_event"
    assert source =~ "fn encode_window_event"
    assert source =~ "atoms::type_atom()"
    assert source =~ "atoms::window_id()"
    assert source =~ "atoms::event()"
    assert source =~ "append_event_value(entries, env, value)"
    assert RustQ.valid?(source, "generated_events.rs")
  end

  test "derives a closed injected event kind decoder" do
    source = rust_source!(EventBoundary)

    for kind <- GPUI.Event.injectable_types() do
      assert source =~ Macro.camelize(to_string(kind))
    end

    assert source =~ "event.map_get(atoms::type_atom())?.decode::<InjectKind>()?"
    assert source =~ "decode_event_value(value)"
    assert RustQ.valid?(source, "generated_event_boundary.rs")
  end
end
