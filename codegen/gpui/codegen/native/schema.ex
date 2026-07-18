defmodule GPUI.Codegen.Native.Schema do
  @moduledoc false

  alias GPUI.Codegen.Native.Decoder
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
    elements = GPUI.Schema.tags()

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
      generated_string_enum_decoder(
        :decode_generated_element_tag,
        :tag,
        :GeneratedElementTag,
        elements,
        :Unknown
      ),
      generated_component_kind_function(components),
      generated_element_decoder(components),
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

  defp generated_decoder_helpers, do: Decoder.asts() ++ Elements.asts()

  defp generated_component_specs(components) do
    kinds = components |> Enum.map(& &1.kind) |> Enum.uniq()
    generated_enum_decl(:GeneratedComponentKind, kinds ++ [:Unknown])
  end

  defp generated_component_contracts(components) do
    components = Enum.filter(components, &component_contract?/1)

    option_structs =
      [
        if(Enum.any?(components, &uses_select_options?/1),
          do: generated_select_option_struct()
        ),
        if(Enum.any?(components, &uses_radio_options?/1),
          do: generated_radio_option_struct()
        )
      ]
      |> Enum.reject(&is_nil/1)

    (option_structs ++
       Enum.flat_map(components, fn component ->
         [generated_component_struct(component), generated_component_decoder(component)]
       end))
    |> Enum.reject(&is_nil/1)
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

  defp uses_select_options?(component),
    do: Enum.any?(component.attrs, fn {_name, type} -> type == :select_options end)

  defp uses_radio_options?(component),
    do: Enum.any?(component.attrs, fn {_name, type} -> type == :radio_options end)

  defp generated_select_option_struct do
    %AST.Struct{
      name: :SelectOptionNode,
      vis: :crate,
      derive: [:Clone, :Debug, :Eq, :PartialEq],
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      fields: [
        %AST.StructField{name: :label, type: T.path(:String), vis: :crate},
        %AST.StructField{name: :value, type: T.path(:String), vis: :crate}
      ]
    }
  end

  defp generated_radio_option_struct do
    %AST.Struct{
      name: :RadioOptionNode,
      vis: :crate,
      derive: [:Clone, :Debug, :Eq, :PartialEq],
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      fields: [
        %AST.StructField{name: :label, type: T.path(:String), vis: :crate},
        %AST.StructField{name: :value, type: T.path(:String), vis: :crate},
        %AST.StructField{name: :disabled, type: T.path(:bool), vis: :crate}
      ]
    }
  end

  defp generated_component_struct(component) do
    fields =
      [%AST.StructField{name: :style, type: T.path(:StyleAttrs), vis: :crate}] ++
        Enum.map(component.attrs, fn {name, type} ->
          %AST.StructField{name: name, type: component_field_type(name, type), vis: :crate}
        end) ++
        if(component.children,
          do: [%AST.StructField{name: :children, type: T.vec(:ElementNode), vis: :crate}],
          else: []
        ) ++
        Enum.map(component.events, fn {name, _attr} ->
          %AST.StructField{name: name, type: T.option(:String), vis: :crate}
        end)

    %AST.Struct{
      name: component_node_name(component),
      vis: :crate,
      derive: [:Clone, :Debug],
      attrs: [A.attr(:cfg, feature: "real-gpui"), A.attr(:allow, [:dead_code])],
      fields: fields
    }
  end

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
        [%AST.EnumVariant{name: :Div, tuple: [T.path(:ContainerNode)]}] ++
          [%AST.EnumVariant{name: :Input, tuple: [T.path(:InputNode)]}] ++
          component_variants ++
          [
            %AST.EnumVariant{name: :Image, tuple: [T.path(:ImageNode)]},
            %AST.EnumVariant{name: :Text, tuple: [T.path(:TextNode)]}
          ]
    }
  end

  defp generated_component_decoder(component) do
    fields =
      [style: A.try(A.call(:decode_style, [:term]))] ++
        Enum.map(component.attrs, fn {name, type} ->
          {name, component_decoder_expr(name, type)}
        end) ++
        if(component.children,
          do: [children: A.try(A.call(:decode_children, [:term]))],
          else: []
        ) ++
        Enum.map(component.events, fn {name, attr} ->
          {name,
           A.try(
             A.call(:component_string_attr, [
               :term,
               A.path_call([:atoms, rust_atom_name(attr)])
             ])
           )}
        end)

    %AST.Function{
      name: decoder_name(component),
      vis: :crate,
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      args: [A.arg(:term, T.path(:Term))],
      returns: T.nif_result(component_node_name(component)),
      body: [
        A.return_stmt(A.ok(A.struct_expr(component_node_name(component), fields)))
      ]
    }
  end

  defp component_field_type(:id, :string), do: T.path(:String)
  defp component_field_type(_name, :string), do: T.option(:String)
  defp component_field_type(_name, {:default, :string}), do: T.path(:String)

  defp component_field_type(_name, {:default, type, _value})
       when type in [:number, :positive_number],
       do: T.path(:f64)

  defp component_field_type(_name, :non_negative_integer), do: T.option(:u64)

  defp component_field_type(_name, {:default, type, _value})
       when type in [:non_negative_integer, :positive_integer],
       do: T.path(:u64)

  defp component_field_type(_name, :positive_integer), do: T.option(:u64)
  defp component_field_type(_name, {:default, {:enum, _values}, _default}), do: T.option(:String)

  defp component_field_type(_name, :boolean), do: T.path(:bool)
  defp component_field_type(_name, {:default, :boolean, _value}), do: T.path(:bool)
  defp component_field_type(_name, :string_list), do: T.vec(:String)
  defp component_field_type(_name, {:enum, _values}), do: T.option(:String)
  defp component_field_type(_name, :select_options), do: T.vec(:SelectOptionNode)
  defp component_field_type(_name, :radio_options), do: T.vec(:RadioOptionNode)

  defp component_decoder_expr(:id, :string),
    do: A.try(A.call(:component_id, [:term]))

  defp component_decoder_expr(name, :string),
    do: A.try(component_attr_call(:component_string_attr, name))

  defp component_decoder_expr(name, {:default, :string}) do
    :component_string_attr
    |> component_attr_call(name)
    |> A.try()
    |> A.method(:unwrap_or_default)
  end

  defp component_decoder_expr(name, {:default, type, default})
       when type in [:number, :positive_number] do
    helper =
      if type == :positive_number,
        do: :component_positive_number_attr,
        else: :component_number_attr

    helper
    |> component_attr_call(name)
    |> A.try()
    |> A.method(:unwrap_or, [A.lit(default)])
  end

  defp component_decoder_expr(name, :non_negative_integer),
    do: A.try(component_attr_call(:component_non_negative_integer_attr, name))

  defp component_decoder_expr(name, {:default, type, default})
       when type in [:non_negative_integer, :positive_integer] do
    helper =
      if type == :positive_integer,
        do: :component_positive_integer_attr,
        else: :component_non_negative_integer_attr

    helper
    |> component_attr_call(name)
    |> A.try()
    |> A.method(:unwrap_or, [A.lit(default)])
  end

  defp component_decoder_expr(name, :positive_integer),
    do: A.try(component_attr_call(:component_positive_integer_attr, name))

  defp component_decoder_expr(name, :boolean) do
    :component_bool_attr
    |> component_attr_call(name)
    |> A.try()
    |> A.method(:unwrap_or, [false])
  end

  defp component_decoder_expr(name, {:default, :boolean, default}) do
    :component_bool_attr
    |> component_attr_call(name)
    |> A.try()
    |> A.method(:unwrap_or, [default])
  end

  defp component_decoder_expr(name, :string_list),
    do: A.try(component_attr_call(:component_string_list_attr, name))

  defp component_decoder_expr(name, {:enum, values}) do
    A.try(
      A.call(:component_enum_attr, [
        :term,
        A.path_call([:atoms, rust_atom_name(name)]),
        A.slice(Enum.map(values, &A.lit/1))
      ])
    )
  end

  defp component_decoder_expr(name, {:default, {:enum, values}, default}) do
    name
    |> component_decoder_expr({:enum, values})
    |> A.method(:or, [A.some(A.method(A.lit(default), :to_string))])
  end

  defp component_decoder_expr(_name, :select_options),
    do: A.try(A.call(:decode_select_options, [:term]))

  defp component_decoder_expr(_name, :radio_options),
    do: A.try(A.call(:decode_radio_options, [:term]))

  defp component_attr_call(helper, name),
    do: A.call(helper, [:term, A.path_call([:atoms, rust_atom_name(name)])])

  defp component_contract?(component),
    do: component.kind |> Atom.to_string() |> String.ends_with?("_component")

  defp component_node_name(component),
    do:
      component.kind
      |> Atom.to_string()
      |> Macro.camelize()
      |> Kernel.<>("Node")
      |> String.to_atom()

  defp decoder_name(component), do: String.to_atom("decode_generated_#{component.kind}")

  defp rust_atom_name(atom) do
    atom
    |> Atom.to_string()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> String.to_atom()
  end

  defp generated_component_kind_function(components) do
    arms =
      Enum.map(components, fn component ->
        %AST.Arm{
          pattern: P.path([:GeneratedElementTag, rust_variant(component.tag)]),
          body: [
            A.return_stmt(A.path([:GeneratedComponentKind, rust_variant(component.kind)]))
          ]
        }
      end) ++
        [
          %AST.Arm{
            pattern: P.path([:GeneratedElementTag, :Unknown]),
            body: [A.return_stmt(A.path([:GeneratedComponentKind, :Unknown]))]
          }
        ]

    %AST.Function{
      name: :generated_component_kind,
      vis: :pub,
      args: [A.arg(:tag, T.path(:GeneratedElementTag))],
      returns: T.path(:GeneratedComponentKind),
      body: [A.return_stmt(A.match_expr(A.var(:tag), arms))]
    }
  end

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

  defp generated_element_decoder(components) do
    arms =
      components
      |> Enum.uniq_by(& &1.kind)
      |> Enum.map(&generated_element_decoder_arm/1)
      |> Kernel.++([
        %AST.Arm{
          pattern: P.path([:GeneratedComponentKind, :Unknown]),
          body: [A.return_stmt(A.err(A.badarg()))]
        }
      ])

    %AST.Function{
      name: :decode_generated_element_node,
      vis: :crate,
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      args: [A.arg(:term, T.path(:Term)), A.arg(:tag, T.path(:GeneratedElementTag))],
      returns: T.nif_result(:ElementNode),
      body: [
        A.return_stmt(A.match_expr(A.call(:generated_component_kind, [:tag]), arms))
      ]
    }
  end

  defp generated_element_decoder_arm(component) do
    kind = rust_variant(component.kind)

    body =
      if component_contract?(component) do
        component
        |> decoder_name()
        |> A.call([:term])
        |> A.method(:map, [A.path([:ElementNode, kind])])
      else
        A.path_call(primitive_decoder_path(component.kind), [:term, :tag])
      end

    %AST.Arm{
      pattern: P.path([:GeneratedComponentKind, kind]),
      body: [A.return_stmt(body)]
    }
  end

  defp primitive_decoder_path(:container), do: [:decode_container_node]
  defp primitive_decoder_path(:input), do: [:decode_input_node]
  defp primitive_decoder_path(:image), do: [:nif, :decode_image_node]
  defp primitive_decoder_path(:text), do: [:decode_text_node]

  defp generated_enum_decl(name, variants) do
    %AST.Enum{
      name: name,
      derive: [:Clone, :Copy, :Debug, :Eq, :PartialEq],
      variants: Enum.map(variants, &%AST.EnumVariant{name: rust_variant(&1)}),
      vis: :pub
    }
  end

  defp generated_string_enum_decoder(name, arg_name, enum_name, values, unknown) do
    arms =
      Enum.map(values, fn value ->
        %AST.Arm{
          pattern: %AST.PatLiteral{value: to_string(value)},
          body: [A.return_stmt(A.path([enum_name, rust_variant(value)]))]
        }
      end) ++
        [
          %AST.Arm{
            pattern: A.wildcard(),
            body: [A.return_stmt(A.path([enum_name, rust_variant(unknown)]))]
          }
        ]

    %AST.Function{
      name: name,
      vis: :pub,
      args: [A.arg(arg_name, T.ref(:str))],
      returns: T.path(enum_name),
      body: [A.return_stmt(%AST.Match{expr: A.var(arg_name), arms: arms})]
    }
  end

  defp rust_variant(value),
    do: value |> Atom.to_string() |> Macro.camelize() |> Identifier.atom!()
end
