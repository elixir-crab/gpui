repository_root = Path.expand("../..", __DIR__)
codegen_root = Path.join(repository_root, "codegen/gpui/codegen/native")

for file <- ~w(
  accessibility.ex
  boundary.ex
  component_contracts.ex
  host.ex
  components.ex
  decoder.ex
  disabled_window.ex
  dispatch.ex
  elements.ex
  event_boundary.ex
  events.ex
  extensions.ex
  style.ex
  test_boundary.ex
  text_boundary.ex
  text_types.ex
  window.ex
  atoms.ex
  resources.ex
  resource_boundary.ex
  rusty.ex
  runtime_boundary.ex
  renderers.ex
  renderer_dispatch.ex
  registry.ex
  schema_types.ex
  schema.ex
  vanilla.ex
  projections.ex
) do
  Code.require_file(file, codegen_root)
end
