project_root = Mix.Project.project_file() |> Path.dirname()

unless Code.ensure_loaded?(GPUI.Schema.Extension) do
  Code.require_file("lib/gpui/schema/extension.ex", project_root)
end

unless Code.ensure_loaded?(GPUI.Event) do
  Code.require_file("lib/gpui/transfer/payload.ex", project_root)
  Code.require_file("lib/gpui/transfer/event.ex", project_root)
  Code.require_file("lib/gpui/event.ex", project_root)
end

unless Code.ensure_loaded?(GPUI.Text.Selection) do
  Code.require_file("lib/gpui/text/position.ex", project_root)
  Code.require_file("lib/gpui/text/range.ex", project_root)
  Code.require_file("lib/gpui/text/selection.ex", project_root)
end

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
) do
  Code.require_file(file, codegen_root)
end
