defmodule GPUI.ComponentSpec do
  @moduledoc false

  alias GPUI.ComponentSpec.Component
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
    %Style{name: :display, field: :display_flex, type: {:atom_eq, :flex}},
    %Style{name: :flex_direction, field: :flex_direction, type: :atom_string},
    %Style{name: :align_items, field: :align_items, type: :atom_string},
    %Style{name: :justify_content, field: :justify_content, type: :atom_string},
    %Style{name: :background, field: :background, type: :rgb},
    %Style{name: :color, field: :color, type: :rgb},
    %Style{name: :font_size, field: :font_size, type: :px},
    %Style{name: :gap, field: :gap, type: :px},
    %Style{name: :padding, field: :padding, type: :px},
    %Style{name: :margin, field: :margin, type: :px},
    %Style{name: :width, field: :width, type: :px},
    %Style{name: :height, field: :height, type: :px},
    %Style{name: :border_radius, field: :border_radius, type: :radius},
    %Style{name: :border_width, field: :border_width, type: :px}
  ]

  @resources [:raster, :resource_ref]

  def components, do: @components
  def styles, do: Enum.map(@styles, & &1.name)
  def style_specs, do: @styles
  def resources, do: @resources
  def tags, do: Enum.map(@components, & &1.tag)

  def events do
    @components
    |> Enum.flat_map(&Keyword.values(&1.events))
    |> Enum.uniq()
  end
end
