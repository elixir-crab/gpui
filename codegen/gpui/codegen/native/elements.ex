defmodule GPUI.Codegen.Native.Elements do
  @moduledoc false

  use RustQ.Meta,
    rust_sources: [
      "native/gpui/src/nif.rs",
      "native/gpui/src/resource.rs",
      "native/gpui/src/element/mod.rs"
    ]

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @type viewport_node :: %{
          required(:children) => R.vec(R.path(:ElementNode))
        }

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

  @type text_surface_node :: %{
          required(:style) => R.path(:StyleAttrs),
          required(:id) => String.t(),
          required(:buffer) => R.resource(R.path(:TextBufferResource)),
          required(:focus_request) => R.u64(),
          required(:disabled) => boolean(),
          required(:soft_wrap) => boolean(),
          required(:show_whitespaces) => boolean(),
          required(:tab_size) => R.u64(),
          required(:hard_tabs) => boolean(),
          required(:geometry_ranges) => R.vec(R.path(:TextRange)),
          required(:transaction) => R.option(String.t()),
          required(:selection_change) => R.option(String.t()),
          required(:viewport_change) => R.option(String.t()),
          required(:geometry_change) => R.option(String.t()),
          required(:range_geometry_change) => R.option(String.t())
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

  @spec decode_viewport_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_viewport_node(term, _tag) do
    {:ok,
     enum_variant(
       ElementNode,
       :viewport,
       struct_literal(ViewportNode, children: unwrap!(decode_children(term)))
     )}
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

  @spec decode_image_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_image_node(term, _tag) do
    attrs = unwrap!(term.map_get(Atoms.attrs()))
    raster = unwrap!(attrs.map_get(Atoms.raster()))

    resource_ref =
      case raster.map_get(Atoms.__type__()) do
        {:ok, type_term} -> atom_eq(type_term, "resource_ref")
        {:error, _missing} -> false
      end

    if resource_ref do
      id = unwrap!(decode_resource_ref(raster))

      {:ok,
       enum_variant(
         ElementNode,
         :image,
         struct_literal(ImageNode,
           image: enum_variant(ImageData, :ref, id),
           style: unwrap!(decode_style(term)),
           label: non_empty_string_attr(term, Atoms.label())
         )
       )}
    else
      raster = unwrap!(decode_raster_resource(raster))
      unwrap!(raster.validate())

      {:ok,
       enum_variant(
         ElementNode,
         :image,
         struct_literal(ImageNode,
           image: enum_variant(ImageData, :raster, raster),
           style: unwrap!(decode_style(term)),
           label: non_empty_string_attr(term, Atoms.label())
         )
       )}
    end
  end

  @spec non_empty_string_attr(term(), atom()) :: R.option(String.t())
  defrustp non_empty_string_attr(term, attr) do
    case string_attr(term, attr) do
      {:some, value} -> if value.is_empty(), do: nil, else: some(value)
      nil -> nil
    end
  end

  @spec text_ranges_attr(term(), atom()) :: R.nif_result(R.vec(R.path(:TextRange)))
  defrustp text_ranges_attr(term, attr) do
    case term.map_get(Atoms.attrs()) do
      {:ok, attrs} ->
        case attrs.map_get(attr) do
          {:ok, value} -> decode_as(value, R.vec(R.path(:TextRange)))
          {:error, _missing} -> {:ok, []}
        end

      {:error, _missing} ->
        {:ok, []}
    end
  end

  @spec decode_text_surface_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_text_surface_node(term, _tag) do
    attrs = unwrap!(term.map_get(Atoms.attrs()))

    {:ok,
     enum_variant(
       ElementNode,
       :text_surface,
       struct_literal(TextSurfaceNode,
         style: unwrap!(decode_style(term)),
         id: decode_as!(attrs.map_get(Atoms.id()), String.t()),
         buffer:
           decode_as!(attrs.map_get(Atoms.buffer()), R.resource(R.path(:TextBufferResource))),
         focus_request:
           unwrap!(component_non_negative_integer_attr(term, Atoms.focus_request())).unwrap_or(0),
         disabled: unwrap!(component_bool_attr(term, Atoms.disabled())).unwrap_or(false),
         soft_wrap: unwrap!(component_bool_attr(term, Atoms.soft_wrap())).unwrap_or(false),
         show_whitespaces:
           unwrap!(component_bool_attr(term, Atoms.show_whitespaces())).unwrap_or(false),
         tab_size: unwrap!(component_positive_integer_attr(term, Atoms.tab_size())).unwrap_or(2),
         hard_tabs: unwrap!(component_bool_attr(term, Atoms.hard_tabs())).unwrap_or(false),
         geometry_ranges: unwrap!(text_ranges_attr(term, Atoms.geometry_ranges())),
         transaction: string_attr(term, Atoms.phx_transaction()),
         selection_change: string_attr(term, Atoms.phx_selection_change()),
         viewport_change: string_attr(term, Atoms.phx_viewport_change()),
         geometry_change: string_attr(term, Atoms.phx_geometry_change()),
         range_geometry_change: string_attr(term, Atoms.phx_range_geometry_change())
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

  @allow :unreachable_patterns
  @spec decode_text_children(term()) :: R.nif_result(String.t())
  defrust decode_text_children(term) do
    children = decode_as!(term.map_get(Atoms.children()), R.vec(term()))

    for child <- children, reduce: {:ok, String.new()} do
      {:ok, text} ->
        case text_fragment(child) do
          {:ok, fragment} -> {:ok, text + fragment.as_str()}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
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
        [:viewport_node, :container_node, :image_node, :text_node, :input_node],
        derive: [:Clone, :Debug],
        attrs: [A.attr(:cfg, feature: "real-gpui")],
        vis: :crate,
        field_vis: :crate
      ) ++
        MetaAST.struct_type_items(
          __MODULE__,
          [:text_surface_node],
          derive: [:Clone],
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
