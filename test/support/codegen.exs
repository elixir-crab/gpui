codegen_root = GPUI.Maintainer.Paths.codegen_native()

for file <- ~w(
  accessibility/definitions.ex
  accessibility.ex
  component_contracts.ex
  host.ex
  component/macros.ex
  components.ex
  component_host_contract/definitions.ex
  component_host_contract.ex
  boundary.ex
  decoder.ex
  disabled_window.ex
  dispatch/definitions.ex
  dispatch.ex
  elements.ex
  event_boundary/definitions.ex
  event_boundary.ex
  event/definitions.ex
  events.ex
  extensions.ex
  style/definitions.ex
  style.ex
  test_boundary.ex
  text_boundary.ex
  text_types.ex
  window.ex
  atoms.ex
  resource/definitions.ex
  resources.ex
  resource_boundary.ex
  disabled_resource_boundary.ex
  rusty.ex
  runtime_boundary.ex
  renderers.ex
  renderer_dispatch/definitions.ex
  renderer_dispatch.ex
  registry/definitions.ex
  registry.ex
  schema_type/macros.ex
  schema_types.ex
  schema.ex
  vanilla/definitions.ex
  vanilla/schema_types.ex
  vanilla/dispatch.ex
  vanilla/registry.ex
  vanilla/renderer_dispatch.ex
  projections.ex
) do
  Code.require_file(file, codegen_root)
end
