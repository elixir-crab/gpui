defmodule GPUI.Codegen.Native.DispatchDefinitions do
  @moduledoc false

  defmacro define_dispatch do
    components = GPUI.Schema.components()
    tags = GPUI.Schema.native_tags()

    declarations = [
      string_enum_decoder(tags),
      component_kind_dispatch(components),
      element_decoder_dispatch(components)
    ]

    quote do
      (unquote_splicing(declarations))
    end
  end

  defp string_enum_decoder(tags) do
    clauses =
      Enum.map(tags, fn tag ->
        {:->, [], [[to_string(tag)], enum_value(:GeneratedElementTag, tag)]}
      end) ++ [{:->, [], [[Macro.var(:_, nil)], enum_value(:GeneratedElementTag, :unknown)]}]

    body = {:case, [], [Macro.var(:tag, nil), [do: clauses]]}

    quote do
      @spec decode_generated_element_tag(R.str()) :: R.path(:GeneratedElementTag)
      defrust(decode_generated_element_tag(tag), do: unquote(body))
    end
  end

  defp component_kind_dispatch(components) do
    clauses =
      Enum.map(components, fn component ->
        {:->, [],
         [
           [enum_pattern(:GeneratedElementTag, component.tag)],
           enum_value(:GeneratedComponentKind, component.kind)
         ]}
      end) ++
        [
          {:->, [],
           [
             [enum_pattern(:GeneratedElementTag, :unknown)],
             enum_value(:GeneratedComponentKind, :unknown)
           ]}
        ]

    body = {:case, [], [Macro.var(:tag, nil), [do: clauses]]}

    quote do
      @spec generated_component_kind(R.path(:GeneratedElementTag)) ::
              R.path(:GeneratedComponentKind)
      defrust(generated_component_kind(tag), do: unquote(body))
    end
  end

  defp element_decoder_dispatch(components) do
    clauses =
      (components
       |> Enum.uniq_by(& &1.kind)
       |> Enum.map(fn component ->
         {:->, [],
          [
            [enum_pattern(:GeneratedComponentKind, component.kind)],
            element_decoder_body(component)
          ]}
       end)) ++
        [
          {:->, [],
           [
             [enum_pattern(:GeneratedComponentKind, :unknown)],
             quote(do: {:error, badarg()})
           ]}
        ]

    body =
      {:case, [], [quote(do: generated_component_kind(tag)), [do: clauses]]}

    quote do
      @allow RustQ.Clippy.lint(:redundant_closure)
      @spec decode_generated_element_node(term(), R.path(:GeneratedElementTag)) ::
              R.nif_result(R.path(:ElementNode))
      defrust(decode_generated_element_node(term, tag), do: unquote(body))
    end
  end

  defp element_decoder_body(component) do
    if component_contract?(component) do
      decoder = String.to_atom("decode_generated_#{component.kind}")
      kind = component.kind

      quote do
        unquote(decoder)(term).map(fn node -> enum_variant(ElementNode, unquote(kind), node) end)
      end
    else
      decoder = primitive_decoder(component.kind)
      quote(do: unquote(decoder)(term, tag))
    end
  end

  defp primitive_decoder(:viewport), do: :decode_viewport_node
  defp primitive_decoder(:container), do: :decode_container_node
  defp primitive_decoder(:anchored_layer), do: :decode_anchored_layer_node
  defp primitive_decoder(:text_surface), do: :decode_text_surface_node
  defp primitive_decoder(:input), do: :decode_input_node
  defp primitive_decoder(:image), do: :decode_image_node
  defp primitive_decoder(:text), do: :decode_text_node

  defp component_contract?(component),
    do: component.kind |> Atom.to_string() |> String.ends_with?("_component")

  defp enum_pattern(type, variant), do: {:enum_variant, [], [{:__aliases__, [], [type]}, variant]}
  defp enum_value(type, variant), do: {:enum_variant, [], [{:__aliases__, [], [type]}, variant]}
end

defmodule GPUI.Codegen.Native.Dispatch do
  @moduledoc false

  use RustQ.Meta,
    callable_modules: [GPUI.Codegen.Native.ComponentDefinitions]

  alias GPUI.Codegen.Native.DispatchDefinitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require DispatchDefinitions
  DispatchDefinitions.define_dispatch()

  @spec items() :: [AST.item()]
  def items do
    Enum.map(MetaAST.functions(__MODULE__), fn
      %{name: :decode_generated_element_tag} = function ->
        %{function | vis: :pub}

      %{name: :generated_component_kind} = function ->
        %{function | vis: :pub}

      function ->
        %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}
    end)
  end
end
