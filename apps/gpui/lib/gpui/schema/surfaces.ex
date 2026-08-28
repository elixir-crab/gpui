defmodule GPUI.Schema.Surfaces do
  @moduledoc "Neutral specialized surfaces implemented directly with vanilla GPUI."
  @behaviour GPUI.Schema.Provider
  @components [
    %{
      __struct__: GPUI.Schema.Component,
      attrs: [
        id: :string,
        edges: {:default, {:enum_list, ["top", "right", "bottom", "left"]}, []},
        size: {:default, :edge_fade_size, 24.0},
        opacity: {:default, :unit_number, 1.0}
      ],
      children: true,
      events: [],
      extension: %{
        __struct__: GPUI.Schema.Extension,
        capabilities: [:linear_gradient, :theme_background],
        id: :edge_fade,
        version: 1
      },
      kind: :edge_fade_component,
      public_hidden_attrs: [],
      public_required_attrs: [],
      public_slots: [],
      required_events: [],
      stateful: false,
      tag: :ui_edge_fade
    },
    %{
      __struct__: GPUI.Schema.Component,
      attrs: [
        id: :string,
        fallback: {:default, {:enum, ["solid", "translucent"]}, "solid"},
        opacity: {:default, :unit_number, 0.82},
        reduced_transparency: {:default, :boolean, false}
      ],
      children: true,
      events: [],
      extension: %{
        __struct__: GPUI.Schema.Extension,
        capabilities: [:solid_fallback, :translucent_fallback, :reduced_transparency],
        id: :frost,
        version: 1
      },
      kind: :frost_component,
      public_hidden_attrs: [],
      public_required_attrs: [],
      public_slots: [],
      required_events: [],
      stateful: false,
      tag: :ui_frost
    },
    %{
      __struct__: GPUI.Schema.Component,
      attrs: [id: :string, commands: {:default, :paint_commands, []}],
      children: false,
      events: [],
      extension: %{
        __struct__: GPUI.Schema.Extension,
        capabilities: [:rect, :line],
        id: :paint,
        version: 1
      },
      kind: :paint_component,
      public_hidden_attrs: [],
      public_required_attrs: [],
      public_slots: [],
      required_events: [],
      stateful: false,
      tag: :ui_paint
    }
  ]
  @impl true
  @spec components() :: [GPUI.Schema.Component.t()]
  def components do
    @components
  end
end
