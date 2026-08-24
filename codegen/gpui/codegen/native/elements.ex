defmodule GPUI.Codegen.Native.Elements do
  @moduledoc "Defines and emits RustQ types and decoders for renderer-independent element trees."

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
          required(:accessibility) => R.path(:AccessibilitySemantics),
          required(:children) => R.vec(R.path(:ElementNode)),
          required(:click) => R.option(String.t()),
          required(:bounds_change) => R.option(String.t()),
          required(:focus_request) => R.u64(),
          required(:focus) => R.option(String.t()),
          required(:blur) => R.option(String.t()),
          required(:motion_request) => R.u64(),
          required(:motion_duration) => R.u64(),
          required(:motion_delay) => R.u64(),
          required(:motion_easing) => String.t(),
          required(:motion_policy) => String.t(),
          required(:motion_from_opacity) => R.f64(),
          required(:motion_from_x) => R.f64(),
          required(:motion_from_y) => R.f64(),
          required(:window_control) => R.option(String.t())
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

  @type rich_text_run_node :: %{
          required(:range) => R.path(:TextRange),
          required(:color) => R.option(R.u32()),
          required(:background) => R.option(R.u32()),
          required(:font_weight) => R.option(String.t()),
          required(:font_style) => R.option(String.t()),
          required(:underline) => R.option(R.u32()),
          required(:underline_style) => R.option(String.t()),
          required(:strikethrough) => R.option(R.u32()),
          required(:link) => R.option(String.t())
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
          required(:auto_grow) => boolean(),
          required(:min_lines) => R.u64(),
          required(:max_lines) => R.u64(),
          required(:submit_policy) => String.t(),
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
          required(:submit) => R.option(String.t()),
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

  @spec decode_element_type(term()) :: R.nif_result(String.t())
  defrustp decode_element_type(term) do
    type_term = unwrap!(term.map_get(Atoms.type_atom()))
    type_term.atom_to_string()
  end

  @spec decode_element_attrs(term()) :: R.nif_result(term())
  defrustp decode_element_attrs(term), do: term.map_get(Atoms.attrs())

  @spec decode_element_children(term()) :: R.nif_result(R.vec(term()))
  defrustp decode_element_children(term) do
    decode_as(unwrap!(term.map_get(Atoms.children())), R.vec(term()))
  end

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
        node_type = unwrap!(decode_element_type(term))
        tag = decode_generated_element_tag(node_type.as_str())
        decode_generated_element_node(term, tag)
    end
  end

  @spec string_attr(term(), atom()) :: R.option(String.t())
  defrust string_attr(term, attr) do
    case decode_element_attrs(term) do
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
         accessibility: unwrap!(decode_accessibility(term)),
         children: unwrap!(decode_children(term)),
         click: string_attr(term, Atoms.phx_click()),
         bounds_change: string_attr(term, Atoms.phx_bounds_change()),
         focus_request:
           unwrap!(component_non_negative_integer_attr(term, Atoms.focus_request())).unwrap_or(0),
         focus: string_attr(term, Atoms.phx_focus()),
         blur: string_attr(term, Atoms.phx_blur()),
         motion_request:
           unwrap!(component_non_negative_integer_attr(term, Atoms.motion_request())).unwrap_or(0),
         motion_duration:
           unwrap!(component_positive_integer_attr(term, Atoms.motion_duration())).unwrap_or(180),
         motion_delay:
           unwrap!(component_non_negative_integer_attr(term, Atoms.motion_delay())).unwrap_or(0),
         motion_easing:
           string_attr(term, Atoms.motion_easing()).unwrap_or("ease_out".to_string()),
         motion_policy:
           string_attr(term, Atoms.motion_policy()).unwrap_or("respect_system".to_string()),
         motion_from_opacity:
           unwrap!(component_number_attr(term, Atoms.motion_from_opacity())).unwrap_or(1.0),
         motion_from_x:
           unwrap!(component_number_attr(term, Atoms.motion_from_x())).unwrap_or(0.0),
         motion_from_y:
           unwrap!(component_number_attr(term, Atoms.motion_from_y())).unwrap_or(0.0),
         window_control: string_attr(term, Atoms.window_control())
       )
     )}
  end

  @spec decode_anchored_layer_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_anchored_layer_node(term, _tag) do
    attrs = unwrap!(decode_element_attrs(term))

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

  @spec decode_image_data(term()) :: R.nif_result(R.path(:ImageData))
  defrustp decode_image_data(raster) do
    resource_ref =
      case raster.map_get(Atoms.__type__()) do
        {:ok, type_term} -> atom_eq(type_term, "resource_ref")
        {:error, _missing} -> false
      end

    if resource_ref do
      {:ok, enum_variant(ImageData, :ref, unwrap!(decode_resource_ref(raster)))}
    else
      raster = unwrap!(decode_raster_resource(raster))
      unwrap!(raster.validate())
      {:ok, enum_variant(ImageData, :raster, raster)}
    end
  end

  @allow Clippy.redundant_field_names()
  @spec decode_image_node(term(), R.path(:GeneratedElementTag)) ::
          R.nif_result(R.path(:ElementNode))
  defrust decode_image_node(term, _tag) do
    attrs = unwrap!(decode_element_attrs(term))
    image = unwrap!(decode_image_data(unwrap!(attrs.map_get(Atoms.raster()))))

    {:ok,
     enum_variant(
       ElementNode,
       :image,
       struct_literal(ImageNode,
         image: image,
         style: unwrap!(decode_style(term)),
         label: non_empty_string_attr(term, Atoms.label())
       )
     )}
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
    case decode_element_attrs(term) do
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

  @spec decode_rich_text_runs(term()) :: R.nif_result(R.vec(R.path(:RichTextRunNode)))
  defrust decode_rich_text_runs(term) do
    case component_attr(term, Atoms.runs()) do
      {:ok, {:some, value}} -> decode_as(value, R.vec(R.path(:RichTextRunNode)))
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
    attrs = unwrap!(decode_element_attrs(term))

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
         auto_grow: unwrap!(component_bool_attr(term, Atoms.auto_grow())).unwrap_or(false),
         min_lines:
           unwrap!(component_positive_integer_attr(term, Atoms.min_lines())).unwrap_or(1),
         max_lines:
           unwrap!(component_positive_integer_attr(term, Atoms.max_lines())).unwrap_or(8),
         submit_policy: string_attr(term, Atoms.submit_policy()).unwrap_or("newline".to_string()),
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
         submit: string_attr(term, Atoms.phx_submit()),
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
    children = unwrap!(decode_element_children(term))

    for child <- children do
      decode_element_node(child)
    end
  end

  @allow :unreachable_patterns
  @spec decode_text_children(term()) :: R.nif_result(String.t())
  defrust decode_text_children(term) do
    children = unwrap!(decode_element_children(term))

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
          [
            :text_decoration_node,
            :text_style_run_node,
            :rich_text_run_node,
            :text_inline_projection_node,
            :text_block_projection_node
          ],
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
