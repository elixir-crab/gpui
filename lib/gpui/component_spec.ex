defmodule GPUI.ComponentSpec do
  @moduledoc false

  alias GPUI.ComponentSpec.Component
  alias GPUI.ComponentSpec.Resource
  alias GPUI.ComponentSpec.Style

  @components [
    %Component{
      tag: :div,
      kind: :container,
      events: [click: :"phx-click"]
    },
    %Component{
      tag: :button,
      kind: :container,
      events: [click: :"phx-click"]
    },
    %Component{tag: :span, kind: :container, events: [click: :"phx-click"]},
    %Component{tag: :scroll, kind: :container, events: [click: :"phx-click"]},
    %Component{tag: :list, kind: :container, events: [click: :"phx-click"]},
    %Component{tag: :item, kind: :container, events: [click: :"phx-click"]},
    %Component{tag: :icon, kind: :text},
    %Component{
      tag: :input,
      kind: :input,
      events: [change: :"phx-change", keydown: :"phx-keydown", keyup: :"phx-keyup"],
      attrs: [value: :string, placeholder: :string]
    },
    %Component{
      tag: :img,
      kind: :image,
      attrs: [raster: :resource]
    },
    %Component{tag: :text, kind: :text}
  ]

  @styles [
    %Style{name: :display, field: :display_flex, type: {:atom_eq, :flex}, render: :flex_if_true},
    %Style{
      name: :flex_direction,
      field: :flex_direction,
      type: :atom_string,
      render: {:enum_methods, [{"column", :flex_col}, {"row", :flex_row}]}
    },
    %Style{
      name: :align_items,
      field: :align_items,
      type: :atom_string,
      render:
        {:enum_methods, [{"center", :items_center}, {"start", :items_start}, {"end", :items_end}]}
    },
    %Style{
      name: :justify_content,
      field: :justify_content,
      type: :atom_string,
      render:
        {:enum_methods,
         [{"center", :justify_center}, {"start", :justify_start}, {"end", :justify_end}]}
    },
    %Style{
      name: :background,
      field: :background,
      type: :rgb,
      render: {:option_method, :bg, :rgb}
    },
    %Style{name: :color, field: :color, type: :rgb, render: {:option_method, :text_color, :rgb}},
    %Style{
      name: :font_size,
      field: :font_size,
      type: :px,
      render: {:option_method, :text_size, :px}
    },
    %Style{name: :gap, field: :gap, type: :px, render: {:option_method, :gap, :px}},
    %Style{name: :padding, field: :padding, type: :px, render: {:option_method, :p, :px}},
    %Style{name: :margin, field: :margin, type: :px, render: {:option_method, :m, :px}},
    %Style{name: :width, field: :width, type: :px, render: {:option_method, :w, :px}},
    %Style{name: :height, field: :height, type: :px, render: {:option_method, :h, :px}},
    %Style{
      name: :border_radius,
      field: :border_radius,
      type: :radius,
      render: {:option_method, :rounded, :px}
    },
    %Style{
      name: :border_width,
      field: :border_width,
      type: :px,
      render: {:option_method, :border, :px}
    }
  ]

  @resources [
    %Resource{
      name: :raster,
      fields: [width: :u32, height: :u32, format: :string, stride: {:option, :u32}, data: :binary]
    },
    %Resource{name: :resource_ref, fields: [id: :string, type: :atom]}
  ]

  def components, do: @components
  def styles, do: Enum.map(@styles, & &1.name)
  def style_specs, do: @styles
  def resources, do: Enum.map(@resources, & &1.name)
  def resource_specs, do: @resources
  def tags, do: Enum.map(@components, & &1.tag)

  def events do
    @components
    |> Enum.flat_map(&Keyword.values(&1.events))
    |> Enum.uniq()
  end
end
