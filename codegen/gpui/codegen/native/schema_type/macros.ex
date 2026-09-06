defmodule GPUI.Codegen.Native.SchemaType.Macros do
  @moduledoc "Builds RustQ element-tag, component-kind, and element-node enums from GPUI.Schema."

  defmacro define_schema_types(host) do
    host = Macro.expand(host, __CALLER__)
    components = GPUI.Codegen.Native.Host.components(host)

    component_kinds = components |> Enum.map(& &1.kind) |> Enum.uniq() |> Kernel.++([:unknown])
    element_tags = GPUI.Codegen.Native.Host.native_tags(host) ++ [:unknown]

    element_variants =
      [
        viewport: [quote(do: R.path(:ViewportNode))],
        div: [quote(do: R.path(:ContainerNode))],
        anchored_layer: [quote(do: R.path(:AnchoredLayerNode))],
        text_surface: [quote(do: R.path(:TextSurfaceNode))],
        input: [quote(do: R.path(:InputNode))]
      ] ++
        (components
         |> Enum.filter(&component_contract?/1)
         |> Enum.map(fn component ->
           {component.kind, [quote(do: R.path(unquote(component_node_name(component))))]}
         end)) ++
        [
          image: [quote(do: R.path(:ImageNode))],
          text: [quote(do: R.path(:TextNode))]
        ]

    quote do
      @type generated_component_kind :: R.enum(unquote(unit_variants(component_kinds)))
      @type generated_element_tag :: R.enum(unquote(unit_variants(element_tags)))
      @type element_node :: R.enum(unquote(element_variants))
    end
  end

  defp unit_variants(values), do: Enum.map(values, &{&1, []})

  defp component_contract?(component),
    do: component.kind |> Atom.to_string() |> String.ends_with?("_component")

  defp component_node_name(component),
    do:
      component.kind
      |> Atom.to_string()
      |> Macro.camelize()
      |> Kernel.<>("Node")
      |> String.to_atom()
end
