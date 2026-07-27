project_root = Mix.Project.project_file() |> Path.dirname()
codegen_root = Path.join(project_root, "codegen/gpui/codegen/native")

for file <- ~w(
  boundary.ex
  component_contracts.ex
  components.ex
  decoder.ex
  dispatch.ex
  elements.ex
  events.ex
  style.ex
  atoms.ex
  resources.ex
  renderers.ex
  renderer_dispatch.ex
  schema_types.ex
  schema.ex
) do
  Code.require_file(file, codegen_root)
end
