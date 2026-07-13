use RustQ.Config

alias RustQ.Rustler.Atom, as: RustlerAtom
alias RustQ.Rustler.Nif

require_file("lib/gpui/schema/component.ex")
require_file("lib/gpui/schema/resource.ex")
require_file("lib/gpui/schema/style.ex")
require_file("lib/gpui/schema.ex")
require_file("codegen/gpui/codegen/native/decoder.ex")
require_file("codegen/gpui/codegen/native/style.ex")
require_file("codegen/gpui/codegen/native/schema.ex")

fixed_atoms = [
  :ok,
  :error,
  :window_closed,
  :missing_resource,
  {:type_atom, "type"},
  :window_id,
  :event,
  :resource_type,
  :size,
  :title,
  :root,
  :tree,
  :children,
  :attrs,
  :__type__,
  :style
]

fixed_atom_values =
  MapSet.new(fixed_atoms, fn
    {_name, value} -> value
    atom -> Atom.to_string(atom)
  end)

component_atoms =
  Enum.flat_map(GPUI.Schema.components(), fn component ->
    Keyword.keys(component.attrs) ++
      Keyword.keys(component.events) ++
      Keyword.values(component.events)
  end)

resource_atoms =
  Enum.flat_map(GPUI.Schema.resource_specs(), fn resource ->
    [resource.name | Keyword.keys(resource.fields)]
  end)

schema_atoms =
  (component_atoms ++ resource_atoms ++ GPUI.Schema.styles())
  |> Enum.uniq()
  |> Enum.reject(&MapSet.member?(fixed_atom_values, Atom.to_string(&1)))
  |> Enum.map(fn atom ->
    value = Atom.to_string(atom)
    rust_name = value |> String.replace(~r/[^a-zA-Z0-9_]/, "_") |> String.to_atom()
    {rust_name, value}
  end)

rust "native/gpui/src/generated/atoms.rs" do
  RustlerAtom.declaration(fixed_atoms ++ schema_atoms)
end

generate "native-schema", "native/gpui/src/generated/schema.rs" do
  content(GPUI.Codegen.Native.Schema.source())
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
  inject_event: []
]

rust "native/gpui/src/generated/nifs.rs" do
  Nif.wrappers_from_source("native/gpui/src/nif.rs", nifs)
end

generate "native-stubs", "lib/gpui/native/generated.ex" do
  content(Nif.stubs_from_source("native/gpui/src/nif.rs", nifs, GPUI.Native.Generated))
end
