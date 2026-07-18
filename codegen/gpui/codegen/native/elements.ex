defmodule GPUI.Codegen.Native.Elements do
  @moduledoc false

  use RustQ.Meta,
    rust_sources: [
      "native/gpui/src/nif.rs",
      "native/gpui/src/element/mod.rs"
    ]

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @type container_node :: %{
          required(:tag) => R.path(:GeneratedElementTag),
          required(:style) => R.path(:StyleAttrs),
          required(:children) => R.vec(R.path(:ElementNode)),
          required(:click) => R.option(String.t())
        }

  @type image_node :: %{
          required(:image) => R.path(:ImageData),
          required(:style) => R.path(:StyleAttrs),
          required(:label) => R.option(String.t())
        }

  @type text_node :: %{
          required(:text) => String.t(),
          required(:style) => R.path(:StyleAttrs)
        }

  @type input_node :: %{
          required(:style) => R.path(:StyleAttrs),
          required(:value) => String.t(),
          required(:placeholder) => R.option(String.t()),
          required(:change) => R.option(String.t()),
          required(:keydown) => R.option(String.t()),
          required(:keyup) => R.option(String.t())
        }

  @spec decode_element_node(term()) :: R.nif_result(R.path(:ElementNode))
  defrust decode_element_node(term) do
    case decode_as(term, String.t()) do
      {:ok, decoded_text} ->
        {:ok,
         enum_variant(
           ElementNode,
           :text,
           struct_literal(TextNode, text: decoded_text, style: default_style())
         )}

      {:error, _reason} ->
        case term.map_get(Atoms.type_atom()) do
          {:ok, type_term} ->
            case type_term.atom_to_string() do
              {:ok, node_type} ->
                tag = decode_generated_element_tag(node_type.as_str())
                decode_generated_element_node(term, tag)

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @spec window_tree(term()) :: R.nif_result(R.path(:ElementNode))
  defrust window_tree(window) do
    case window.map_get(Atoms.root()) do
      {:ok, root} ->
        case root.map_get(Atoms.tree()) do
          {:ok, tree} -> decode_element_node(tree)
          {:error, _missing} -> {:ok, ElementNode.empty_root()}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec string_attr(term(), atom()) :: R.option(String.t())
  defrust string_attr(term, attr) do
    case term.map_get(Atoms.attrs()) do
      {:ok, attrs} ->
        case attrs.map_get(attr) do
          {:ok, value} -> decode_as(value, String.t()).ok()
          {:error, _missing} -> nil
        end

      {:error, _missing} ->
        nil
    end
  end

  @spec decode_container_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_container_node(term, element_tag) do
    {:ok,
     enum_variant(
       ElementNode,
       :div,
       struct_literal(ContainerNode,
         tag: element_tag,
         style: unwrap!(decode_style(term)),
         children: unwrap!(decode_children(term)),
         click: string_attr(term, Atoms.phx_click())
       )
     )}
  end

  @spec decode_input_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_input_node(term, _tag) do
    {:ok,
     enum_variant(
       ElementNode,
       :input,
       struct_literal(InputNode,
         style: unwrap!(decode_style(term)),
         value: string_attr(term, Atoms.value()).unwrap_or_default(),
         placeholder: string_attr(term, Atoms.placeholder()),
         change: string_attr(term, Atoms.phx_change()),
         keydown: string_attr(term, Atoms.phx_keydown()),
         keyup: string_attr(term, Atoms.phx_keyup())
       )
     )}
  end

  @spec decode_children(term()) :: R.nif_result(R.vec(R.path(:ElementNode)))
  defrust decode_children(term) do
    children = decode_as!(term.map_get(Atoms.children()), R.vec(term()))

    for child <- children do
      decode_element_node(child)
    end
  end

  @spec decode_text_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_text_node(term, _tag) do
    {:ok,
     enum_variant(
       ElementNode,
       :text,
       struct_literal(TextNode,
         text: unwrap!(decode_text_children(term)),
         style: unwrap!(decode_style(term))
       )
     )}
  end

  def items do
    structs =
      MetaAST.struct_type_items(
        __MODULE__,
        [:container_node, :image_node, :text_node, :input_node],
        derive: [:Clone, :Debug],
        attrs: [A.attr(:cfg, feature: "real-gpui")],
        vis: :crate,
        field_vis: :crate
      )

    structs ++ asts()
  end

  def asts do
    Enum.map(MetaAST.functions(__MODULE__), fn ast ->
      %{ast | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | ast.attrs]}
    end)
  end
end
