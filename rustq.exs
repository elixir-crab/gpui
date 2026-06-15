use RustQ.Config

alias RustQ.Rustler

require_file "lib/gpui/command_spec.ex"
require_file "lib/gpui/codegen.ex"

rust "native/gpui_native/src/generated_atoms.rs" do
  Rustler.atoms([:ok, :error, :invalid_tree])
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
    drain_events: [
      args: [env: "Env<'a>", runtime: "ResourceArc<RuntimeResource>"],
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
