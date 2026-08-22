use RustQ.Config

alias RustQ.Meta.AST, as: MetaAST
alias RustQ.Rustler.Atom, as: RustlerAtom
alias RustQ.Rustler.Nif

require_file("lib/gpui/schema/component.ex")
require_file("lib/gpui/schema/component_docs.ex")
require_file("lib/gpui/schema/resource.ex")
require_file("lib/gpui/schema/style.ex")
require_file("lib/gpui/accessibility.ex")
require_file("lib/gpui/text/position.ex")
require_file("lib/gpui/text/range.ex")
require_file("lib/gpui/text/rich_run.ex")
require_file("lib/gpui/schema.ex")
require_file("codegen/gpui/codegen/native/accessibility.ex")
require_file("codegen/gpui/codegen/native/boundary.ex")
require_file("codegen/gpui/codegen/native/component_contracts.ex")
require_file("codegen/gpui/codegen/native/components.ex")
require_file("codegen/gpui/codegen/native/decoder.ex")
require_file("codegen/gpui/codegen/native/disabled_window.ex")
require_file("codegen/gpui/codegen/native/dispatch.ex")
require_file("codegen/gpui/codegen/native/elements.ex")
require_file("codegen/gpui/codegen/native/events.ex")
require_file("codegen/gpui/codegen/native/style.ex")
require_file("codegen/gpui/codegen/native/window.ex")
require_file("codegen/gpui/codegen/native/atoms.ex")
require_file("codegen/gpui/codegen/native/resources.ex")
require_file("codegen/gpui/codegen/native/rusty.ex")
require_file("codegen/gpui/codegen/native/renderers.ex")
require_file("codegen/gpui/codegen/native/renderer_dispatch.ex")
require_file("codegen/gpui/codegen/native/registry.ex")
require_file("codegen/gpui/codegen/native/schema_types.ex")
require_file("codegen/gpui/codegen/native/schema.ex")

rust "native/gpui/src/generated/atoms.rs" do
  RustlerAtom.declaration(GPUI.Codegen.Native.Atoms.all())
end

rust "native/gpui/src/generated/disabled_window.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.DisabledWindow)
end

rust "native/gpui/src/generated/window.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.Window)
end

rust "native/gpui/src/generated/resources.rs" do
  GPUI.Codegen.Native.Resources.items()
end

rust "native/gpui/src/generated/events.rs" do
  GPUI.Codegen.Native.Events.items()
end

rust "native/gpui/src/generated/rusty.rs" do
  RustQ.Native.items(GPUI.Codegen.Native.Rusty)
end

rust "native-schema", "native/gpui/src/generated/schema.rs" do
  GPUI.Codegen.Native.Schema.items()
end

rust "component-registry", "native/gpui/src/generated/component_registry.rs" do
  GPUI.Codegen.Native.Schema.registry_items()
end

nifs = GPUI.Codegen.Native.Boundary.nifs()

generate "disabled-nifs", "native/gpui/src/generated/disabled_nifs.rs" do
  content(
    RustQ.render_file!(
      "codegen/gpui/codegen/native/templates/disabled_nifs.rs",
      splice: [items: GPUI.Codegen.Native.Boundary.disabled_items()],
      rustfmt: true
    )
  )
end

rust "native/gpui/src/generated/nifs.rs" do
  Nif.wrappers_from_source("native/gpui/src/nif.rs", nifs)
end

generate "native-test-facade", "lib/gpui/native/test.ex" do
  content(GPUI.Codegen.Native.Boundary.native_test_facade_source())
end

generate "native-stubs", "lib/gpui/native/generated.ex" do
  rusty_functions =
    GPUI.Codegen.Native.Rusty
    |> RustQ.Native.items()
    |> Enum.flat_map(fn
      %RustQ.Rust.AST.Function{name: :decode_image} = function -> [function]
      _item -> []
    end)

  generated =
    Nif.stubs_from_functions(
      Nif.functions_from_source("native/gpui/src/nif.rs", nifs) ++
        Enum.map(rusty_functions, &{:decode_image, &1}) ++
        [
          update_window: MetaAST.function!(GPUI.Codegen.Native.Window, :update_window),
          close_window: MetaAST.function!(GPUI.Codegen.Native.Window, :close_window),
          await_frame: MetaAST.function!(GPUI.Codegen.Native.Window, :await_frame),
          frame_token: MetaAST.function!(GPUI.Codegen.Native.Window, :frame_token),
          await_frame_after: MetaAST.function!(GPUI.Codegen.Native.Window, :await_frame_after),
          set_theme: MetaAST.function!(GPUI.Codegen.Native.Window, :set_theme)
        ],
      GPUI.Native.Generated
    )

  content(
    GPUI.Codegen.Native.Boundary.document_generated_module(
      generated,
      "Generated Rustler NIF declarations used by GPUI.Native."
    )
  )
end
