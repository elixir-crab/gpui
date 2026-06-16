use RustQ.Config

alias RustQ.Rustler

require_file "lib/gpui/component_spec/component.ex"
require_file "lib/gpui/component_spec/resource.ex"
require_file "lib/gpui/component_spec/style.ex"
require_file "lib/gpui/component_spec.ex"
require_file "lib/gpui/codegen.ex"

rust "native/gpui/src/generated_atoms.rs" do
  Rustler.atoms([:ok, :error, :invalid_tree, :click, :window_updated])
end

generate "native-element-schema", "native/gpui/src/generated_element_schema.rs" do
  content GPUI.Codegen.generated_native_element_schema()
end

rust "native/gpui/src/generated_nifs.rs" do
  Rustler.nif_exports(
    start_runtime: [
      args: [env: "Env<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    open_window: [
      args: [env: "Env<'a>", runtime: "ResourceArc<RuntimeResource>", window: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a,
      schedule: :dirty_cpu
    ],
    update_window: [
      args: [env: "Env<'a>", runtime: "ResourceArc<RuntimeResource>", window_id: :u64, tree: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a,
      schedule: :dirty_cpu
    ],
    put_resource: [
      args: [env: "Env<'a>", runtime: "ResourceArc<RuntimeResource>", resource_id: "String", resource: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a,
      schedule: :dirty_cpu
    ],
    drop_resource: [
      args: [env: "Env<'a>", runtime: "ResourceArc<RuntimeResource>", resource_id: "String"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    drain_events: [
      args: [env: "Env<'a>", runtime: "ResourceArc<RuntimeResource>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    emit_test_event: [
      args: [env: "Env<'a>", runtime: "ResourceArc<RuntimeResource>", event: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    validate_tree: [
      args: [env: "Env<'a>", tree: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a,
      schedule: :dirty_cpu
    ]
  )
end
