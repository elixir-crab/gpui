defmodule GPUI.Schema.Surfaces do
  @moduledoc "Neutral specialized surfaces implemented directly with vanilla GPUI."
  @behaviour GPUI.Schema.Provider
  @components [
    %{
      __struct__: GPUI.Schema.Component,
      tag: :ui_terminal,
      kind: :terminal_component,
      attrs: [
        id: :string,
        label: :required_string,
        columns: {:default, :positive_integer, 80},
        cursor_row: {:default, :non_negative_integer, 0},
        cursor_column: {:default, :non_negative_integer, 0},
        cursor_visible: {:default, :boolean, true},
        font_family: {:default, :string},
        font_size: {:default, :positive_number, 14.0},
        line_height: {:default, :positive_number, 20.0},
        focus_request: {:default, :non_negative_integer, 0},
        reset_request: {:default, :non_negative_integer, 0},
        disabled: :boolean
      ],
      children: true,
      events: [
        keystroke: :"phx-keystroke",
        text: :"phx-text",
        paste: :"phx-paste",
        resize: :"phx-resize",
        range: :"phx-range"
      ],
      extension: %{
        __struct__: GPUI.Schema.Extension,
        id: :terminal,
        version: 1,
        capabilities: [:cell_grid, :raw_keyboard, :committed_text, :clipboard, :cell_geometry]
      },
      public_hidden_attrs: [],
      public_required_attrs: [:id, :label],
      public_slots: [],
      required_events: [],
      stateful: false
    },
    %{
      __struct__: GPUI.Schema.Component,
      tag: :ui_terminal_row,
      kind: :terminal_row_component,
      attrs: [],
      children: true,
      events: [],
      extension: nil,
      public_hidden_attrs: [],
      public_required_attrs: [],
      public_slots: [],
      required_events: [],
      stateful: false
    },
    %{
      __struct__: GPUI.Schema.Component,
      tag: :ui_terminal_cell,
      kind: :terminal_cell_component,
      attrs: [text: :required_string, columns: {:default, :positive_integer, 1}, italic: :boolean],
      children: false,
      events: [],
      extension: nil,
      public_hidden_attrs: [],
      public_required_attrs: [:text],
      public_slots: [],
      required_events: [],
      stateful: false
    },
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
