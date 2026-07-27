defmodule GPUI.Codegen.Native.Schema do
  @moduledoc false

  alias GPUI.Codegen.Native.ComponentContracts
  alias GPUI.Codegen.Native.ComponentDefinitions
  alias GPUI.Codegen.Native.Decoder
  alias GPUI.Codegen.Native.Dispatch
  alias GPUI.Codegen.Native.Elements
  alias GPUI.Codegen.Native.RendererDispatch
  alias GPUI.Codegen.Native.SchemaTypes
  alias GPUI.Codegen.Native.Style
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.PatternBuilder, as: P
  alias RustQ.Rust.AST.TypeBuilder, as: T

  @spec items() :: [AST.item()]
  def items do
    components = GPUI.Schema.components()

    [
      SchemaTypes.component_kind_item(),
      generated_decoder_helpers(),
      Style.items(GPUI.Schema.style_specs()),
      generated_component_contracts(components),
      SchemaTypes.element_node_item(),
      SchemaTypes.element_tag_item(),
      Dispatch.items(),
      RendererDispatch.item()
    ]
    |> List.flatten()
  end

  @spec registry_items() :: [AST.item()]
  def registry_items do
    components = GPUI.Schema.stateful_components()

    [
      generated_registry_kind(components),
      generated_registry_state(components),
      generated_registry_impl(components)
    ]
  end

  defp generated_decoder_helpers, do: Decoder.asts() ++ Elements.items()

  defp generated_component_contracts(_components) do
    ComponentContracts.items() ++ ComponentDefinitions.items()
  end

  defp generated_registry_kind(components) do
    %AST.Enum{
      name: :ComponentKind,
      derive: [:Clone, :Copy, :Debug, :Eq, :Hash, :PartialEq],
      variants: Enum.map(components, &%AST.EnumVariant{name: registry_variant(&1)})
    }
  end

  defp generated_registry_state(components) do
    %AST.Enum{
      name: :StatefulComponent,
      variants:
        Enum.map(components, fn component ->
          %AST.EnumVariant{
            name: registry_variant(component),
            tuple: [T.path(registry_type(component))]
          }
        end)
    }
  end

  defp generated_registry_impl(components) do
    components
    |> Enum.flat_map(fn component ->
      [generated_registry_getter(component), generated_registry_inserter(component)]
    end)
    |> then(&A.impl(:ComponentRegistry, items: &1))
  end

  defp generated_registry_getter(component) do
    variant = registry_variant(component)
    type = registry_type(component)
    method = registry_method(component)

    %AST.Function{
      name: String.to_atom("#{method}_mut"),
      vis: :crate,
      args: [A.receiver(mut: true), A.arg(:id, T.ref(:str))],
      returns: T.option(T.mut_ref(type)),
      body: [
        A.let(
          :key,
          A.path_call([:ComponentKey, :new], [A.path([:ComponentKind, variant]), :id])
        ),
        A.stmt(A.method(A.field(:self, :active), :insert, [A.method(:key, :clone)])),
        A.return_stmt(
          A.match_expr(
            A.method(A.field(:self, :entries), :get_mut, [A.ref(:key)]),
            [
              %AST.Arm{
                pattern: P.some(P.path_tuple([:StatefulComponent, variant], [:component])),
                body: [A.return_stmt(A.some(:component))]
              },
              %AST.Arm{pattern: P.wildcard(), body: [A.return_stmt(A.none())]}
            ]
          )
        )
      ]
    }
  end

  defp generated_registry_inserter(component) do
    variant = registry_variant(component)
    type = registry_type(component)
    method = registry_method(component)

    %AST.Function{
      name: String.to_atom("insert_#{method}"),
      vis: :crate,
      args: [A.receiver(mut: true), A.arg(:id, T.ref(:str)), A.arg(:component, T.path(type))],
      returns: T.path(:bool),
      body: [
        A.let(
          :key,
          A.path_call([:ComponentKey, :new], [A.path([:ComponentKind, variant]), :id])
        ),
        A.stmt(A.method(A.field(:self, :active), :insert, [A.method(:key, :clone)])),
        A.return_stmt(
          A.method(
            A.method(A.field(:self, :entries), :insert, [
              :key,
              A.path_call([:StatefulComponent, variant], [:component])
            ]),
            :is_none
          )
        )
      ]
    }
  end

  defp registry_method(component) do
    component.kind
    |> Atom.to_string()
    |> String.replace_suffix("_component", "")
  end

  defp registry_variant(component),
    do: component |> registry_method() |> Macro.camelize() |> String.to_atom()

  defp registry_type(component),
    do: component |> registry_variant() |> then(&String.to_atom("Component#{&1}"))
end
