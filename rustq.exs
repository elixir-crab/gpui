use RustQ.Config

alias RustQ.Rustler

require_file "lib/gpui/schema/component.ex"
require_file "lib/gpui/schema/resource.ex"
require_file "lib/gpui/schema/style.ex"
require_file "lib/gpui/schema.ex"
require_file "codegen/gpui/codegen/native/style.ex"
require_file "codegen/gpui/codegen/native/schema.ex"

rust "native/gpui/src/generated/atoms.rs" do
  Rustler.atoms([:ok, :error, :invalid_tree, :click])
end

generate "native-schema", "native/gpui/src/generated/schema.rs" do
  content GPUI.Codegen.Native.Schema.source()
end

nifs = [
  start_runtime: [],
  open_window: [schedule: :dirty_cpu],
  update_window: [schedule: :dirty_cpu],
  close_window: [schedule: :dirty_cpu],
  stop_runtime: [schedule: :dirty_cpu],
  put_resource: [schedule: :dirty_cpu],
  drop_resource: [],
  drain_events: [],
  inject_event: [],
  validate_tree: [schedule: :dirty_cpu]
]

rust "native/gpui/src/generated/nifs.rs" do
  Rustler.nif_exports_from_source("native/gpui/src/nif.rs", nifs, lifetime: :a)
end

generate "native-stubs", "lib/gpui/native/generated.ex" do
  content Rustler.nif_stubs_from_source("native/gpui/src/nif.rs", nifs, GPUI.Native.Generated)
end
