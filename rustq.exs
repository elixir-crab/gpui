use RustQ.Config

alias RustQ.Rustler

require_file "lib/gpui/command_spec.ex"
require_file "lib/gpui/codegen.ex"

rust "native/gpui_native/src/generated_atoms.rs" do
  Rustler.atoms([:ok, :error, :invalid_tree, :click, :window_updated])
end

generate "native-element-schema", "native/gpui_native/src/generated_element_schema.rs" do
  content GPUI.Codegen.generated_native_element_schema()
end

rust "native/gpui_native/src/generated_nifs.rs" do
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

generate "commands", "native/gpui_host/src/generated_commands.rs" do
  content GPUI.Codegen.generated_host_commands()
end
