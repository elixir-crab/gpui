use RustQ.Config

alias RustQ.Meta.AST, as: MetaAST
alias RustQ.Rustler.Atom, as: RustlerAtom
alias RustQ.Rustler.Nif

require_file("apps/gpui/lib/gpui/schema/extension.ex")
require_file("apps/gpui/lib/gpui/schema/component.ex")
require_file("apps/gpui/lib/gpui/schema/component_docs.ex")
require_file("apps/gpui/lib/gpui/schema/resource.ex")
require_file("apps/gpui/lib/gpui/schema/style.ex")
require_file("apps/gpui/lib/gpui/schema/registry.ex")
require_file("apps/gpui/lib/gpui/schema/provider.ex")
require_file("apps/gpui/lib/gpui/accessibility.ex")
require_file("apps/gpui/lib/gpui/text/position.ex")
require_file("apps/gpui/lib/gpui/text/range.ex")
require_file("apps/gpui/lib/gpui/text/selection.ex")
require_file("apps/gpui/lib/gpui/text/rich_run.ex")
require_file("apps/gpui/lib/gpui/schema/core.ex")
require_file("apps/gpui/lib/gpui/schema/surfaces.ex")
require_file("apps/gpui_components/lib/gpui/components/schema_declarations.ex")
require_file("apps/gpui_components/lib/gpui/components/native_contract.ex")
require_file("apps/gpui/lib/gpui/schema.ex")
require_file("apps/gpui_components/lib/gpui/components/schema.ex")
require_file("codegen/gpui/codegen/native/host.ex")
require_file("apps/gpui/lib/gpui/transfer/payload.ex")
require_file("apps/gpui/lib/gpui/transfer/event.ex")
require_file("apps/gpui/lib/gpui/event.ex")
require_file("codegen/gpui/codegen/native/accessibility.ex")
require_file("codegen/gpui/codegen/native/boundary.ex")
require_file("codegen/gpui/codegen/native/component_contracts.ex")
require_file("codegen/gpui/codegen/native/component_host_contract.ex")
require_file("codegen/gpui/codegen/native/component_adapters.ex")
require_file("codegen/gpui/codegen/native/component_event_transport.ex")
require_file("codegen/gpui/codegen/native/component_nodes.ex")
require_file("codegen/gpui/codegen/native/core_style.ex")
require_file("codegen/gpui/codegen/native/core_style_application.ex")
require_file("codegen/gpui/codegen/native/components.ex")
require_file("codegen/gpui/codegen/native/decoder.ex")
require_file("codegen/gpui/codegen/native/disabled_window.ex")
require_file("codegen/gpui/codegen/native/dispatch.ex")
require_file("codegen/gpui/codegen/native/elements.ex")
require_file("codegen/gpui/codegen/native/event_boundary.ex")
require_file("codegen/gpui/codegen/native/events.ex")
require_file("codegen/gpui/codegen/native/extensions.ex")
require_file("codegen/gpui/codegen/native/style.ex")
require_file("codegen/gpui/codegen/native/style_adapter.ex")
require_file("codegen/gpui/codegen/native/test_boundary.ex")
require_file("codegen/gpui/codegen/native/text_boundary.ex")
require_file("codegen/gpui/codegen/native/text_types.ex")
require_file("codegen/gpui/codegen/native/window.ex")
require_file("codegen/gpui/codegen/native/atoms.ex")
require_file("codegen/gpui/codegen/native/resources.ex")
require_file("codegen/gpui/codegen/native/resource_boundary.ex")
require_file("codegen/gpui/codegen/native/rusty.ex")
require_file("codegen/gpui/codegen/native/runtime_boundary.ex")
require_file("codegen/gpui/codegen/native/renderers.ex")
require_file("codegen/gpui/codegen/native/renderer_dispatch.ex")
require_file("codegen/gpui/codegen/native/registry.ex")
require_file("codegen/gpui/codegen/native/schema_types.ex")
require_file("codegen/gpui/codegen/native/schema.ex")
require_file("codegen/gpui/codegen/native/vanilla.ex")
require_file("codegen/gpui/codegen/native/projections.ex")

rust "native-component-event-transport", "apps/gpui_native/native/src/generated/component_event_transport.rs" do
  GPUI.Codegen.Native.ComponentEventTransport.items()
end

rust "native-component-adapters", "apps/gpui_native/native/src/generated/component_adapters.rs" do
  GPUI.Codegen.Native.ComponentAdapters.items()
end

rust "apps/gpui_native/native/src/generated/atoms.rs" do
  RustlerAtom.declaration(GPUI.Codegen.Native.Atoms.all())
end

rust "apps/gpui_native/native/src/generated/disabled_window.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.DisabledWindow)
end

rust "native-style-adapter", "apps/gpui_native/native/src/generated/style_adapter.rs" do
  GPUI.Codegen.Native.StyleAdapter.items()
end

rust "apps/gpui_native/native/src/generated/test_boundary.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.TestBoundary)
end

rust "apps/gpui_native/native/src/generated/text_boundary.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.TextBoundary)
end

rust "apps/gpui_native/native/src/generated/text_types.rs" do
  GPUI.Codegen.Native.TextTypes.items()
end

rust "apps/gpui_native/native/src/generated/window.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.Window)
end

rust "apps/gpui_native/native/src/generated/resources.rs" do
  GPUI.Codegen.Native.Resources.items()
end

rust "apps/gpui_native/native/src/generated/resource_boundary.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.ResourceBoundary)
end

rust "apps/gpui_native/native/src/generated/disabled_resource_boundary.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.DisabledResourceBoundary)
end

rust "apps/gpui_native/native/src/generated/extensions.rs" do
  GPUI.Codegen.Native.Extensions.items()
end

rust "apps/gpui_native/native/src/generated/events.rs" do
  GPUI.Codegen.Native.Events.items()
end

rust "apps/gpui_native/native/src/generated/event_boundary.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.EventBoundary)
end

rust "apps/gpui_native/native/src/generated/runtime_boundary.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.RuntimeBoundary)
end

rust "apps/gpui_native/native/src/generated/rusty.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.Rusty)
end

rust "gpui-core-style", "apps/gpui/native/src/generated/style.rs" do
  GPUI.Codegen.Native.CoreStyle.items()
end

rust "gpui-core-style-application", "apps/gpui/native/src/generated/style_application.rs" do
  GPUI.Codegen.Native.CoreStyleApplication.items()
end

rust "vanilla-schema", "apps/gpui/native/src/generated/schema.rs" do
  GPUI.Codegen.Native.Projections.schema_items(:vanilla)
end

rust "vanilla-component-registry", "apps/gpui/native/src/generated/component_registry.rs" do
  GPUI.Codegen.Native.Projections.registry_items(:vanilla)
end

rust "gpui-component-host-contract", "apps/gpui_components/native/src/generated/host_contract.rs" do
  GPUI.Codegen.Native.ComponentHostContract.items()
end

rust "gpui-component-nodes", "apps/gpui_components/native/src/generated/nodes.rs" do
  GPUI.Codegen.Native.ComponentNodes.items()
end

rust "gpui-component-schema", "apps/gpui_components/native/src/generated/schema.rs" do
  GPUI.Codegen.Native.Projections.schema_items(:gpui_component)
end

rust "gpui-component-registry", "apps/gpui_components/native/src/generated/component_registry.rs" do
  GPUI.Codegen.Native.Projections.registry_items(:gpui_component)
end

rust "native-schema", "apps/gpui_native/native/src/generated/schema.rs" do
  GPUI.Codegen.Native.Schema.items()
end

rust "component-registry", "apps/gpui_native/native/src/generated/component_registry.rs" do
  GPUI.Codegen.Native.Schema.registry_items()
end

generate "native-test-facade", "apps/gpui/lib/gpui/native_test.ex" do
  content(GPUI.Codegen.Native.Boundary.native_test_facade_source())
end

generate "native-stubs", "apps/gpui/lib/gpui/native_generated.ex" do
  rusty_functions =
    GPUI.Codegen.Native.Rusty
    |> RustQ.Native.items()
    |> Enum.flat_map(fn
      %RustQ.Rust.AST.Function{name: :decode_image} = function -> [function]
      _item -> []
    end)

  generated =
    Nif.stubs_from_functions(
      Enum.map(rusty_functions, &{:decode_image, &1}) ++
        [
          text_buffer_new:
            MetaAST.function!(GPUI.Codegen.Native.TextBoundary, :text_buffer_new),
          text_buffer_snapshot:
            MetaAST.function!(GPUI.Codegen.Native.TextBoundary, :text_buffer_snapshot),
          text_buffer_transact:
            MetaAST.function!(GPUI.Codegen.Native.TextBoundary, :text_buffer_transact),
          text_buffer_undo:
            MetaAST.function!(GPUI.Codegen.Native.TextBoundary, :text_buffer_undo),
          text_buffer_redo:
            MetaAST.function!(GPUI.Codegen.Native.TextBoundary, :text_buffer_redo),
          host_info: MetaAST.function!(GPUI.Codegen.Native.RuntimeBoundary, :host_info),
          start_runtime:
            MetaAST.function!(GPUI.Codegen.Native.RuntimeBoundary, :start_runtime),
          stop_runtime: MetaAST.function!(GPUI.Codegen.Native.RuntimeBoundary, :stop_runtime),
          open_window: MetaAST.function!(GPUI.Codegen.Native.Window, :open_window),
          update_window: MetaAST.function!(GPUI.Codegen.Native.Window, :update_window),
          close_window: MetaAST.function!(GPUI.Codegen.Native.Window, :close_window),
          await_frame: MetaAST.function!(GPUI.Codegen.Native.Window, :await_frame),
          frame_token: MetaAST.function!(GPUI.Codegen.Native.Window, :frame_token),
          await_frame_after: MetaAST.function!(GPUI.Codegen.Native.Window, :await_frame_after),
          set_theme: MetaAST.function!(GPUI.Codegen.Native.Window, :set_theme),
          put_resource:
            MetaAST.function!(GPUI.Codegen.Native.ResourceBoundary, :put_resource),
          drop_resource:
            MetaAST.function!(GPUI.Codegen.Native.ResourceBoundary, :drop_resource),
          drain_events: MetaAST.function!(GPUI.Codegen.Native.EventBoundary, :drain_events),
          inject_event: MetaAST.function!(GPUI.Codegen.Native.EventBoundary, :inject_event),
          native_test_start:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_start),
          native_test_render:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_render),
          native_test_resize:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_resize),
          native_test_bounds:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_bounds),
          native_test_focus:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_focus),
          native_test_click:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_click),
          native_test_click_at:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_click_at),
          native_test_scroll:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_scroll),
          native_test_input:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_input),
          native_test_key:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_key),
          native_test_advance:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_advance),
          native_test_idle:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_idle),
          native_test_events:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_events),
          native_test_stop:
            MetaAST.function!(GPUI.Codegen.Native.TestBoundary, :native_test_stop)
        ],
      GPUI.Native.Generated
    )

  content(
    GPUI.Codegen.Native.Boundary.document_generated_module(
      generated,
      "Generated Rustler NIF declarations loaded by GPUI.Native.NIF."
    )
  )
end

generate "native-facade", "apps/gpui/lib/gpui/native_facade.ex" do
  content(
    GPUI.Codegen.Native.Boundary.native_facade_source(
      File.read!("apps/gpui/lib/gpui/native_generated.ex")
    )
  )
end
