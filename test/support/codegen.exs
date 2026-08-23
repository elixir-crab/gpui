project_root = Mix.Project.project_file() |> Path.dirname()
codegen_root = Path.join(project_root, "codegen/gpui/codegen/native")

for file <- ~w(
  accessibility.ex
  boundary.ex
  component_contracts.ex
  components.ex
  decoder.ex
  disabled_window.ex
  dispatch.ex
  elements.ex
  event_boundary.ex
  events.ex
  style.ex
  window.ex
  atoms.ex
  resources.ex
  resource_boundary.ex
  rusty.ex
  renderers.ex
  renderer_dispatch.ex
  registry.ex
  schema_types.ex
  schema.ex
) do
  Code.require_file(file, codegen_root)
end
