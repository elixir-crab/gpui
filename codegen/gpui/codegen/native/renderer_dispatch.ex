defmodule GPUI.Codegen.Native.RendererDispatchDefinitions do
  @moduledoc "Builds renderer calls from schema entries and discovered handwritten Rust functions."

  defmacro define_renderer_dispatch do
    components =
      GPUI.Codegen.Native.Host.components()
      |> Enum.filter(&component_contract?/1)

    nodes = Enum.map(components, &component_node_name/1)
    renderers = GPUI.Codegen.Native.Renderers.for_nodes!(nodes)

    {clauses, module_declarations} =
      components
      |> Enum.with_index()
      |> Enum.map_reduce([], fn {component, index}, declarations ->
        renderer = Map.fetch!(renderers, component_node_name(component))
        alias_name = String.to_atom("Renderer#{index}")
        rust_module = Enum.drop(renderer.path, -1)

        alias_ast = {:__aliases__, [], [alias_name]}

        declaration =
          quote do
            defrustmod(unquote(alias_ast), as: unquote(rust_module))
          end

        pattern =
          {:enum_variant, [],
           [{:__aliases__, [], [:ElementNode]}, component.kind, Macro.var(:node, nil)]}

        call = renderer_call(renderer, alias_name)
        clause = {:->, [], [[pattern], call]}
        {clause, [declaration | declarations]}
      end)

    clauses = clauses ++ [{:->, [], [[Macro.var(:_, nil)], quote(do: unreachable!())]}]
    module_declarations = Enum.reverse(module_declarations)

    body = {:case, [], [Macro.var(:node, nil), [do: clauses]]}

    quote do
      unquote_splicing(module_declarations)

      @spec render_generated_component_node(
              R.path(:ElementNode),
              R.usize(),
              R.mut_ref(R.raw(:"element::ElementRenderContext<'_, '_>"))
            ) :: R.path({:gpui, :AnyElement})
      defrust(render_generated_component_node(node, element_id, context), do: unquote(body))
    end
  end

  defp renderer_call(renderer, alias_name) do
    module = {:__aliases__, [], [alias_name]}
    function = List.last(renderer.path)
    args = Enum.map(renderer.args, &Macro.var(&1, nil))
    {{:., [], [module, function]}, [], args}
  end

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

defmodule GPUI.Codegen.Native.RendererDispatch do
  @moduledoc "Emits schema-derived dispatch from decoded element nodes to native renderers."

  use RustQ.Meta

  alias GPUI.Codegen.Native.RendererDispatchDefinitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require RendererDispatchDefinitions
  RendererDispatchDefinitions.define_renderer_dispatch()

  @spec item() :: AST.Function.t()
  def item do
    function = MetaAST.function!(__MODULE__, :render_generated_component_node)
    %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}
  end
end
