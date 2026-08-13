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
          required(:id) => R.option(String.t()),
          required(:accessibility_role) => R.option(String.t()),
          required(:accessibility_label) => R.option(String.t()),
          required(:accessibility_description) => R.option(String.t()),
          required(:accessibility_value) => R.option(String.t()),
          required(:accessibility_selected) => R.option(boolean()),
          required(:accessibility_expanded) => R.option(boolean()),
          required(:accessibility_checked) => R.option(String.t()),
          required(:accessibility_orientation) => R.option(String.t()),
          required(:children) => R.vec(R.path(:ElementNode)),
          required(:click) => R.option(String.t()),
          required(:bounds_change) => R.option(String.t()),
          required(:focus_request) => R.u64(),
          required(:focus) => R.option(String.t()),
          required(:blur) => R.option(String.t())
        }

  @type anchored_layer_node :: %{
          required(:id) => String.t(),
          required(:anchor) => String.t(),
          required(:position_mode) => String.t(),
          required(:position_x) => R.option(R.f64()),
          required(:position_y) => R.option(R.f64()),
          required(:offset_x) => R.f64(),
          required(:offset_y) => R.f64(),
          required(:fit) => String.t(),
          required(:margin) => R.f64(),
          required(:priority) => R.u64(),
          required(:children) => R.vec(R.path(:ElementNode))
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

  @type text_decoration_node :: %{
          required(:range) => R.path(:TextRange),
          required(:background) => R.option(R.u32()),
          required(:underline) => R.option(R.u32()),
          required(:underline_style) => String.t()
        }

  @type text_style_run_node :: %{
          required(:range) => R.path(:TextRange),
          required(:color) => R.option(R.u32()),
          required(:font_weight) => R.option(String.t()),
          required(:font_style) => R.option(String.t())
        }

  @type text_inline_projection_node :: %{
          required(:position) => R.path(:TextPosition),
          required(:text) => String.t(),
          required(:color) => R.u32()
        }

  @type text_block_projection_node :: %{
          required(:line) => R.u64(),
          required(:text) => String.t(),
          required(:placement) => String.t(),
          required(:height) => R.u64(),
          required(:color) => R.u32(),
          required(:background) => R.option(R.u32())
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
          required(:scroll_request) => R.u64(),
          required(:scroll_to) => R.option(R.path(:TextPosition)),
          required(:decorations) => R.vec(R.path(:TextDecorationNode)),
          required(:style_runs) => R.vec(R.path(:TextStyleRunNode)),
          required(:inline_projections) => R.vec(R.path(:TextInlineProjectionNode)),
          required(:block_projections) => R.vec(R.path(:TextBlockProjectionNode)),
          required(:transaction) => R.option(String.t()),
          required(:selection_change) => R.option(String.t()),
          required(:viewport_change) => R.option(String.t()),
          required(:geometry_change) => R.option(String.t()),
          required(:range_geometry_change) => R.option(String.t()),
          required(:hit_test) => R.option(String.t()),
          required(:focus) => R.option(String.t()),
          required(:blur) => R.option(String.t())
        }

  @type input_node :: %{
          required(:style) => R.path(:StyleAttrs),
          required(:id) => R.option(String.t()),
          required(:value) => String.t(),
          required(:placeholder) => R.option(String.t()),
          required(:focus_request) => R.u64(),
          required(:change) => R.option(String.t()),
          required(:keydown) => R.option(String.t()),
          required(:keyup) => R.option(String.t()),
          required(:focus) => R.option(String.t()),
          required(:blur) => R.option(String.t())
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

  @allow RustQ.Clippy.lint(:useless_vec)
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
         id: non_empty_string_attr(term, Atoms.id()),
         accessibility_role:
           unwrap!(
             component_enum_attr(
               term,
               Atoms.accessibility_role(),
               ref([
                 "button",
                 "dialog",
                 "group",
                 "heading",
                 "image",
                 "label",
                 "link",
                 "list",
                 "list_item",
                 "progress",
                 "radio",
                 "slider",
                 "splitter",
                 "tab",
                 "tab_list",
                 "tab_panel",
                 "text",
                 "textbox",
                 "tree",
                 "tree_item"
               ])
             )
           ),
         accessibility_label: non_empty_string_attr(term, Atoms.accessibility_label()),
         accessibility_description:
           non_empty_string_attr(term, Atoms.accessibility_description()),
         accessibility_value: non_empty_string_attr(term, Atoms.accessibility_value()),
         accessibility_selected:
           unwrap!(component_bool_attr(term, Atoms.accessibility_selected())),
         accessibility_expanded:
           unwrap!(component_bool_attr(term, Atoms.accessibility_expanded())),
         accessibility_checked:
           unwrap!(
             component_enum_attr(
               term,
               Atoms.accessibility_checked(),
               ref(["false", "true", "mixed"])
             )
           ),
         accessibility_orientation:
           unwrap!(
             component_enum_attr(
               term,
               Atoms.accessibility_orientation(),
               ref(["horizontal", "vertical"])
             )
           ),
         children: unwrap!(decode_children(term)),
         click: string_attr(term, Atoms.phx_click()),
         bounds_change: string_attr(term, Atoms.phx_bounds_change()),
         focus_request:
           unwrap!(component_non_negative_integer_attr(term, Atoms.focus_request())).unwrap_or(0),
         focus: string_attr(term, Atoms.phx_focus()),
         blur: string_attr(term, Atoms.phx_blur())
       )
     )}
  end

  @spec decode_anchored_layer_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_anchored_layer_node(term, _tag) do
    attrs = unwrap!(term.map_get(Atoms.attrs()))

    {:ok,
     enum_variant(
       ElementNode,
       :anchored_layer,
       struct_literal(AnchoredLayerNode,
         id: decode_as!(attrs.map_get(Atoms.id()), String.t()),
         anchor: string_attr(term, Atoms.anchor()).unwrap_or("top_left".to_string()),
         position_mode: string_attr(term, Atoms.position_mode()).unwrap_or("local".to_string()),
         position_x: unwrap!(component_number_attr(term, Atoms.position_x())),
         position_y: unwrap!(component_number_attr(term, Atoms.position_y())),
         offset_x: unwrap!(component_number_attr(term, Atoms.offset_x())).unwrap_or(0.0),
         offset_y: unwrap!(component_number_attr(term, Atoms.offset_y())).unwrap_or(0.0),
         fit: string_attr(term, Atoms.fit()).unwrap_or("switch_anchor".to_string()),
         margin: unwrap!(component_number_attr(term, Atoms.margin())).unwrap_or(0.0),
         priority:
           unwrap!(component_non_negative_integer_attr(term, Atoms.priority())).unwrap_or(0),
         children: unwrap!(decode_children(term))
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

  @spec text_position_attr(term(), atom()) :: R.nif_result(R.option(R.path(:TextPosition)))
  defrustp text_position_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> {:ok, some(decode_as!(value, R.path(:TextPosition)))}
      {:ok, nil} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec text_decorations_attr(term(), atom()) ::
          R.nif_result(R.vec(R.path(:TextDecorationNode)))
  defrustp text_decorations_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> decode_as(value, R.vec(R.path(:TextDecorationNode)))
      {:ok, nil} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec text_style_runs_attr(term(), atom()) ::
          R.nif_result(R.vec(R.path(:TextStyleRunNode)))
  defrustp text_style_runs_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> decode_as(value, R.vec(R.path(:TextStyleRunNode)))
      {:ok, nil} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec text_inline_projections_attr(term(), atom()) ::
          R.nif_result(R.vec(R.path(:TextInlineProjectionNode)))
  defrustp text_inline_projections_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> decode_as(value, R.vec(R.path(:TextInlineProjectionNode)))
      {:ok, nil} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec text_block_projections_attr(term(), atom()) ::
          R.nif_result(R.vec(R.path(:TextBlockProjectionNode)))
  defrustp text_block_projections_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> decode_as(value, R.vec(R.path(:TextBlockProjectionNode)))
      {:ok, nil} -> {:ok, []}
      {:error, reason} -> {:error, reason}
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
         scroll_request:
           unwrap!(component_non_negative_integer_attr(term, Atoms.scroll_request())).unwrap_or(0),
         scroll_to: unwrap!(text_position_attr(term, Atoms.scroll_to())),
         decorations: unwrap!(text_decorations_attr(term, Atoms.decorations())),
         style_runs: unwrap!(text_style_runs_attr(term, Atoms.style_runs())),
         inline_projections:
           unwrap!(text_inline_projections_attr(term, Atoms.inline_projections())),
         block_projections: unwrap!(text_block_projections_attr(term, Atoms.block_projections())),
         transaction: string_attr(term, Atoms.phx_transaction()),
         selection_change: string_attr(term, Atoms.phx_selection_change()),
         viewport_change: string_attr(term, Atoms.phx_viewport_change()),
         geometry_change: string_attr(term, Atoms.phx_geometry_change()),
         range_geometry_change: string_attr(term, Atoms.phx_range_geometry_change()),
         hit_test: string_attr(term, Atoms.phx_hit_test()),
         focus: string_attr(term, Atoms.phx_focus()),
         blur: string_attr(term, Atoms.phx_blur())
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
         id: non_empty_string_attr(term, Atoms.id()),
         value: string_attr(term, Atoms.value()).unwrap_or_default(),
         placeholder: string_attr(term, Atoms.placeholder()),
         focus_request:
           unwrap!(component_non_negative_integer_attr(term, Atoms.focus_request())).unwrap_or(0),
         change: string_attr(term, Atoms.phx_change()),
         keydown: string_attr(term, Atoms.phx_keydown()),
         keyup: string_attr(term, Atoms.phx_keyup()),
         focus: string_attr(term, Atoms.phx_focus()),
         blur: string_attr(term, Atoms.phx_blur())
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
        [
          :viewport_node,
          :container_node,
          :anchored_layer_node,
          :image_node,
          :text_node,
          :input_node
        ],
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
        ) ++
        MetaAST.struct_type_items(
          __MODULE__,
          [:text_decoration_node, :text_style_run_node, :text_inline_projection_node, :text_block_projection_node],
          derive: [:Clone, :Debug, :NifMap],
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
