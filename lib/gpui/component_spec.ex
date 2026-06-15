defmodule GPUI.ComponentSpec do
  @moduledoc false

  @components [
    %{
      tag: :div,
      kind: :container,
      events: [click: :"phx-click"],
      attrs: []
    },
    %{
      tag: :button,
      kind: :container,
      events: [click: :"phx-click"],
      attrs: []
    },
    %{
      tag: :input,
      kind: :input,
      events: [change: :"phx-change", keydown: :"phx-keydown", keyup: :"phx-keyup"],
      attrs: [value: :string, placeholder: :string]
    },
    %{
      tag: :img,
      kind: :image,
      events: [],
      attrs: [raster: :resource]
    },
    %{
      tag: :text,
      kind: :text,
      events: [],
      attrs: []
    }
  ]

  @styles [
    :display,
    :flex_direction,
    :align_items,
    :justify_content,
    :background,
    :color,
    :font_size,
    :gap,
    :padding,
    :margin,
    :width,
    :height,
    :border_radius,
    :border_width
  ]

  @resources [:raster, :resource_ref]

  def components, do: @components
  def styles, do: @styles
  def resources, do: @resources
  def tags, do: Enum.map(@components, & &1.tag)

  def events do
    @components
    |> Enum.flat_map(&Keyword.values(&1.events))
    |> Enum.uniq()
  end
end
