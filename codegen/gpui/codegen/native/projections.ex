defmodule GPUI.Codegen.Native.Projections do
  @moduledoc "Renders immutable schema projections into their future crate owners."

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  @spec schema_items(:vanilla | :gpui_component) :: [AST.item()]
  def schema_items(:gpui_component), do: GPUI.Codegen.Native.Schema.items()

  def schema_items(:vanilla) do
    component_items = component_items(GPUI.Codegen.Native.Vanilla.Definitions, :vanilla)

    [
      type_item!(GPUI.Codegen.Native.Vanilla.SchemaTypes, :GeneratedComponentKind,
        derive: [:Clone, :Copy, :Debug, :Eq, :PartialEq]
      ),
      GPUI.Codegen.Native.Decoder.asts(),
      GPUI.Codegen.Native.Elements.items(),
      GPUI.Codegen.Native.Style.items(GPUI.Schema.style_specs()),
      GPUI.Codegen.Native.Accessibility.items(),
      component_items,
      type_item!(GPUI.Codegen.Native.Vanilla.SchemaTypes, :ElementNode,
        derive: [:Clone, :Debug],
        attrs: [A.attr(:cfg, feature: "real-gpui")],
        vis: :crate
      ),
      type_item!(GPUI.Codegen.Native.Vanilla.SchemaTypes, :GeneratedElementTag,
        derive: [:Clone, :Copy, :Debug, :Eq, :PartialEq]
      ),
      dispatch_items(GPUI.Codegen.Native.Vanilla.Dispatch),
      renderer_item(GPUI.Codegen.Native.Vanilla.RendererDispatch)
    ]
    |> List.flatten()
    |> Enum.map(&allow_vanilla_dead_code/1)
  end
  @spec registry_items(:vanilla | :gpui_component) :: [AST.item()]
  def registry_items(:gpui_component), do: GPUI.Codegen.Native.Schema.registry_items()
  def registry_items(:vanilla), do: build_registry_items(GPUI.Codegen.Native.Vanilla.Registry)

  defp allow_vanilla_dead_code(%AST.Function{name: name} = item)
       when name in [
              :component_optional_number_pair_attr,
              :component_number_pair_attr,
              :component_string_list_attr,
              :decode_rich_text_runs
            ],
       do: %{item | attrs: [A.attr(:allow, [:dead_code]) | item.attrs]}

  defp allow_vanilla_dead_code(%AST.Struct{name: :RichTextRunNode} = item),
    do: %{item | attrs: [A.attr(:allow, [:dead_code]) | item.attrs]}

  defp allow_vanilla_dead_code(item), do: item

  defp component_items(module, host) do
    components =
      host
      |> GPUI.Codegen.Native.Host.components()
      |> Enum.filter(&String.ends_with?(Atom.to_string(&1.kind), "_component"))

    structs =
      module
      |> MetaAST.struct_type_items(
        Enum.map(components, &String.to_atom("#{&1.kind}_node")),
        derive: [:Clone, :Debug],
        attrs: [A.attr(:cfg, feature: "real-gpui"), A.attr(:allow, [:dead_code])],
        vis: :crate,
        field_vis: :crate
      )
      |> Map.new(&{&1.name, &1})

    functions =
      module
      |> MetaAST.functions()
      |> Map.new(&{&1.name, %{&1 | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | &1.attrs]}})

    Enum.flat_map(components, fn component ->
      node = component.kind |> Atom.to_string() |> Macro.camelize() |> Kernel.<>("Node") |> String.to_atom()
      decoder = String.to_atom("decode_generated_#{component.kind}")
      [Map.fetch!(structs, node), Map.fetch!(functions, decoder)]
    end)
  end

  defp type_item!(module, name, opts) do
    item = MetaAST.enum_type_item!(module, name)
    %{
      item
      | derive: Keyword.fetch!(opts, :derive),
        attrs: Keyword.get(opts, :attrs, item.attrs),
        vis: Keyword.get(opts, :vis, :pub)
    }
  end

  defp dispatch_items(module) do
    Enum.map(MetaAST.functions(module), fn
      %{name: name} = function
      when name in [:decode_generated_element_tag, :generated_component_kind] ->
        %{function | vis: :pub}

      function ->
        %{
          function
          | vis: :crate,
            attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]
        }
    end)
  end

  defp renderer_item(module) do
    function = MetaAST.function!(module, :render_generated_component_node)
    %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}
  end

  defp build_registry_items(module) do
    type_items = MetaAST.generated_type_items(module)
    component_kind = Enum.find(type_items, &match?(%AST.Enum{name: :ComponentKind}, &1))
    stateful_component = Enum.find(type_items, &match?(%AST.Enum{name: :StatefulComponent}, &1))
    impl = MetaAST.impl!(module, :ComponentRegistry)

    [
      %{component_kind | derive: [:Clone, :Copy, :Debug, :Eq, :Hash, :PartialEq], vis: nil},
      %{
        stateful_component
        | derive: [],
          attrs: [A.allow_attr(A.path([:clippy, :large_enum_variant]))],
          vis: nil
      },
      impl
    ]
  end
end
