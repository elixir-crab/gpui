defmodule GPUI.Codegen.Native.Schema do
  @moduledoc false

  alias GPUI.Codegen.Native.ComponentContracts
  alias GPUI.Codegen.Native.ComponentDefinitions
  alias GPUI.Codegen.Native.Decoder
  alias GPUI.Codegen.Native.Dispatch
  alias GPUI.Codegen.Native.Elements
  alias GPUI.Codegen.Native.Renderers
  alias GPUI.Codegen.Native.Style
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.PatternBuilder, as: P
  alias RustQ.Rust.AST.TypeBuilder, as: T
  alias RustQ.Rust.Identifier

  @spec items() :: [AST.item()]
  def items do
    components = GPUI.Schema.components()
    elements = GPUI.Schema.native_tags()

    renderer_nodes =
      components
      |> Enum.filter(&component_contract?/1)
      |> Enum.map(&component_node_name/1)

    renderers = Renderers.for_nodes!(renderer_nodes)

    [
      generated_component_specs(components),
      generated_decoder_helpers(),
      Style.items(GPUI.Schema.style_specs()),
      generated_component_contracts(components),
      generated_element_node_enum(components),
      generated_enum_decl(:GeneratedElementTag, elements ++ [:Unknown]),
      Dispatch.items(),
      generated_component_renderer(components, renderers)
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

  defp generated_component_specs(components) do
    kinds = components |> Enum.map(& &1.kind) |> Enum.uniq()
    generated_enum_decl(:GeneratedComponentKind, kinds ++ [:Unknown])
  end

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

  defp generated_element_node_enum(components) do
    component_variants =
      components
      |> Enum.filter(&component_contract?/1)
      |> Enum.map(fn component ->
        %AST.EnumVariant{
          name: rust_variant(component.kind),
          tuple: [T.path(component_node_name(component))]
        }
      end)

    %AST.Enum{
      name: :ElementNode,
      vis: :crate,
      derive: [:Clone, :Debug],
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      variants:
        [%AST.EnumVariant{name: :Viewport, tuple: [T.path(:ViewportNode)]}] ++
          [%AST.EnumVariant{name: :Div, tuple: [T.path(:ContainerNode)]}] ++
          [%AST.EnumVariant{name: :Input, tuple: [T.path(:InputNode)]}] ++
          component_variants ++
          [
            %AST.EnumVariant{name: :Image, tuple: [T.path(:ImageNode)]},
            %AST.EnumVariant{name: :Text, tuple: [T.path(:TextNode)]}
          ]
    }
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

  defp generated_component_renderer(components, renderers) do
    arms =
      components
      |> Enum.filter(&component_contract?/1)
      |> Enum.map(fn component ->
        variant = rust_variant(component.kind)
        renderer = Map.fetch!(renderers, component_node_name(component))

        %AST.Arm{
          pattern: P.path_tuple([:ElementNode, variant], [:node]),
          body: [A.return_stmt(A.path_call(renderer.path, renderer.args))]
        }
      end)
      |> Kernel.++([
        %AST.Arm{
          pattern: P.wildcard(),
          body: [A.return_stmt(A.macro_call(:unreachable))]
        }
      ])

    %AST.Function{
      name: :render_generated_component_node,
      vis: :crate,
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      args: [
        A.arg(:node, T.path(:ElementNode)),
        A.arg(:element_id, T.path(:usize)),
        A.arg(
          :context,
          T.mut_ref(T.path([:element, :ElementRenderContext], lifetimes: [:_, :_]))
        )
      ],
      returns: T.path([:gpui, :AnyElement]),
      body: [A.return_stmt(A.match_expr(:node, arms))]
    }
  end

  defp generated_enum_decl(name, variants) do
    %AST.Enum{
      name: name,
      derive: [:Clone, :Copy, :Debug, :Eq, :PartialEq],
      variants: Enum.map(variants, &%AST.EnumVariant{name: rust_variant(&1)}),
      vis: :pub
    }
  end

  defp rust_variant(value),
    do: value |> Atom.to_string() |> Macro.camelize() |> Identifier.atom!()
end
