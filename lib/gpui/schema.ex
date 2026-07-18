defmodule GPUI.Schema do
  @moduledoc false

  alias GPUI.Schema.Component
  alias GPUI.Schema.Resource
  alias GPUI.Schema.Style

  @components [
    %Component{tag: :div, kind: :container, events: [click: :"phx-click"]},
    %Component{tag: :button, kind: :container, events: [click: :"phx-click"]},
    %Component{
      tag: :ui_button,
      kind: :button_component,
      events: [click: :"phx-click"],
      children: true,
      attrs: [
        id: :string,
        label: :string,
        variant:
          {:enum, ~w(default primary secondary danger warning success info ghost link text)},
        size: {:enum, ~w(xs sm md lg)},
        disabled: :boolean,
        selected: :boolean,
        loading: :boolean,
        outline: :boolean,
        compact: :boolean
      ]
    },
    %Component{
      tag: :ui_progress,
      kind: :progress_component,
      attrs: [
        id: :string,
        label: :string,
        value: {:default, :number, 0.0},
        max: {:default, :positive_number, 100.0},
        indeterminate: :boolean
      ]
    },
    %Component{
      tag: :ui_file_picker,
      kind: :file_picker_component,
      events: [change: :"phx-change"],
      attrs: [
        id: :string,
        label: :string,
        prompt: :string,
        max_bytes: {:default, :positive_number, 26_214_400.0},
        disabled: :boolean
      ]
    },
    %Component{
      tag: :ui_copy_button,
      kind: :copy_button_component,
      events: [click: :"phx-click"],
      attrs: [id: :string, label: :string, text: {:default, :string}, disabled: :boolean]
    },
    %Component{
      tag: :ui_popover,
      kind: :popover_component,
      stateful: true,
      events: [change: :"phx-change"],
      children: true,
      attrs: [
        id: :string,
        open: :boolean,
        anchor:
          {:enum,
           ~w(top_left top_center top_right bottom_left bottom_center bottom_right left_center right_center)},
        appearance: {:default, :boolean, true},
        closable: {:default, :boolean, true}
      ]
    },
    %Component{tag: :ui_popover_trigger, kind: :popover_trigger_component, children: true},
    %Component{tag: :ui_popover_content, kind: :popover_content_component, children: true},
    %Component{
      tag: :ui_tooltip,
      kind: :tooltip_component,
      children: true,
      attrs: [
        id: :string,
        text: {:default, :string},
        delay: {:default, :number, 500.0},
        hoverable: :boolean
      ]
    },
    %Component{tag: :ui_tooltip_trigger, kind: :tooltip_trigger_component, children: true},
    %Component{
      tag: :ui_dialog,
      kind: :dialog_component,
      stateful: true,
      events: [change: :"phx-change"],
      children: true,
      attrs: [
        id: :string,
        open: :boolean,
        title: :string,
        width: {:default, :number, 448.0},
        overlay: {:default, :boolean, true},
        closable: {:default, :boolean, true},
        keyboard: {:default, :boolean, true},
        close_button: {:default, :boolean, true}
      ]
    },
    %Component{tag: :ui_dialog_trigger, kind: :dialog_trigger_component, children: true},
    %Component{tag: :ui_dialog_content, kind: :dialog_content_component, children: true},
    %Component{
      tag: :ui_dropdown_menu,
      kind: :dropdown_menu_component,
      stateful: true,
      events: [change: :"phx-change", select: :"phx-select"],
      children: true,
      attrs: [
        id: :string,
        open: :boolean,
        anchor:
          {:enum,
           ~w(top_left top_center top_right bottom_left bottom_center bottom_right left_center right_center)},
        disabled: :boolean
      ]
    },
    %Component{
      tag: :ui_dropdown_menu_trigger,
      kind: :dropdown_menu_trigger_component,
      children: true
    },
    %Component{
      tag: :ui_dropdown_menu_item,
      kind: :dropdown_menu_item_component,
      attrs: [
        value: {:default, :string},
        label: {:default, :string},
        disabled: :boolean,
        checked: :boolean
      ]
    },
    %Component{
      tag: :ui_checkbox,
      kind: :checkbox_component,
      events: [change: :"phx-change"],
      children: true,
      attrs: [
        id: :string,
        label: :string,
        size: {:enum, ~w(xs sm md lg)},
        checked: :boolean,
        disabled: :boolean
      ]
    },
    %Component{
      tag: :ui_input,
      kind: :input_component,
      stateful: true,
      events: [change: :"phx-change"],
      attrs: [
        id: :string,
        value: {:default, :string},
        placeholder: :string,
        size: {:enum, ~w(xs sm md lg)},
        disabled: :boolean,
        cleanable: :boolean,
        masked: :boolean,
        loading: :boolean
      ]
    },
    %Component{
      tag: :ui_select,
      kind: :select_component,
      stateful: true,
      events: [change: :"phx-change"],
      attrs: [
        id: :string,
        value: :string,
        options: :select_options,
        placeholder: :string,
        size: {:enum, ~w(xs sm md lg)},
        disabled: :boolean,
        cleanable: :boolean
      ]
    },
    %Component{
      tag: :ui_combobox,
      kind: :combobox_component,
      stateful: true,
      events: [change: :"phx-change", search: :"phx-search"],
      attrs: [
        id: :string,
        value: :string,
        options: :select_options,
        placeholder: :string,
        search_placeholder: :string,
        size: {:enum, ~w(xs sm md lg)},
        disabled: :boolean,
        cleanable: :boolean,
        loading: :boolean
      ]
    },
    %Component{
      tag: :ui_switch,
      kind: :switch_component,
      events: [change: :"phx-change"],
      attrs: [
        id: :string,
        checked: :boolean,
        label: :string,
        size: {:enum, ~w(xs sm md lg)},
        disabled: :boolean,
        loading: :boolean
      ]
    },
    %Component{
      tag: :ui_radio_group,
      kind: :radio_group_component,
      events: [change: :"phx-change"],
      attrs: [
        id: :string,
        value: :string,
        options: :radio_options,
        orientation: {:enum, ~w(horizontal vertical)},
        size: {:enum, ~w(xs sm md lg)},
        disabled: :boolean
      ]
    },
    %Component{
      tag: :ui_accordion,
      kind: :accordion_component,
      events: [change: :"phx-change"],
      children: true,
      attrs: [
        id: :string,
        expanded: :string_list,
        multiple: :boolean,
        bordered: {:default, :boolean, true},
        size: {:enum, ~w(xs sm md lg)},
        disabled: :boolean
      ]
    },
    %Component{
      tag: :ui_accordion_item,
      kind: :accordion_item_component,
      children: true,
      attrs: [id: :string, title: :string, disabled: :boolean]
    },
    %Component{
      tag: :ui_virtual_list,
      kind: :virtual_list_component,
      stateful: true,
      events: [change: :"phx-change", range: :"phx-range"],
      children: true,
      attrs: [
        id: :string,
        label: :string,
        selected: :string,
        selected_index: :non_negative_integer,
        reveal: :string,
        reveal_index: :non_negative_integer,
        reveal_strategy: {:enum, ~w(nearest top center bottom)},
        total_count: {:default, :non_negative_integer, 0},
        offset: {:default, :non_negative_integer, 0},
        overscan: {:default, :non_negative_integer, 8},
        item_height: {:default, :positive_number, 40.0},
        disabled: :boolean
      ]
    },
    %Component{
      tag: :ui_virtual_list_item,
      kind: :virtual_list_item_component,
      children: true,
      attrs: [id: :string, disabled: :boolean]
    },
    %Component{
      tag: :ui_tabs,
      kind: :tabs_component,
      events: [change: :"phx-change"],
      attrs: [
        id: :string,
        value: :string,
        options: :select_options,
        variant: {:enum, ~w(tab outline pill segmented underline)},
        size: {:enum, ~w(xs sm md lg)},
        disabled: :boolean,
        menu: :boolean
      ]
    },
    %Component{
      tag: :ui_slider,
      kind: :slider_component,
      stateful: true,
      events: [change: :"phx-change", release: :"phx-release"],
      attrs: [
        id: :string,
        value: {:default, :number, 0.0},
        min: {:default, :number, 0.0},
        max: {:default, :number, 100.0},
        step: {:default, :number, 1.0},
        orientation: {:enum, ~w(horizontal vertical)},
        scale: {:enum, ~w(linear logarithmic)},
        disabled: :boolean,
        reverse: :boolean
      ]
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
    %Component{tag: :img, kind: :image, attrs: [raster: :resource, label: :string]},
    %Component{tag: :text, kind: :text}
  ]

  @styles [
    %Style{
      name: :display,
      field: :display,
      type: :atom_string,
      render:
        {:enum_methods, [{"flex", :flex}, {"block", :block}, {"grid", :grid}, {"none", :hidden}]}
    },
    %Style{
      name: :flex_direction,
      field: :flex_direction,
      type: :atom_string,
      render:
        {:enum_methods,
         [
           {"column", :flex_col},
           {"column_reverse", :flex_col_reverse},
           {"row", :flex_row},
           {"row_reverse", :flex_row_reverse}
         ]}
    },
    %Style{
      name: :align_items,
      field: :align_items,
      type: :atom_string,
      render:
        {:enum_methods,
         [
           {"center", :items_center},
           {"start", :items_start},
           {"end", :items_end},
           {"baseline", :items_baseline},
           {"stretch", :items_stretch}
         ]}
    },
    %Style{
      name: :justify_content,
      field: :justify_content,
      type: :atom_string,
      render:
        {:enum_methods,
         [
           {"center", :justify_center},
           {"start", :justify_start},
           {"end", :justify_end},
           {"between", :justify_between},
           {"around", :justify_around},
           {"evenly", :justify_evenly}
         ]}
    },
    %Style{
      name: :flex_wrap,
      field: :flex_wrap,
      type: :atom_string,
      render:
        {:enum_methods,
         [{"wrap", :flex_wrap}, {"wrap_reverse", :flex_wrap_reverse}, {"nowrap", :flex_nowrap}]}
    },
    %Style{
      name: :flex_grow,
      field: :flex_grow,
      type: :number,
      render: {:option_method, :flex_grow, :f32}
    },
    %Style{
      name: :flex_shrink,
      field: :flex_shrink,
      type: :number,
      render: {:option_method, :flex_shrink, :f32}
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
    %Style{
      name: :font_weight,
      field: :font_weight,
      type: :atom_string,
      render:
        {:enum_values, :font_weight,
         [
           {"light", [:gpui, :FontWeight, :LIGHT]},
           {"normal", [:gpui, :FontWeight, :NORMAL]},
           {"medium", [:gpui, :FontWeight, :MEDIUM]},
           {"semibold", [:gpui, :FontWeight, :SEMIBOLD]},
           {"bold", [:gpui, :FontWeight, :BOLD]}
         ]}
    },
    %Style{
      name: :line_height,
      field: :line_height,
      type: :px,
      render: {:option_method, :line_height, :px}
    },
    %Style{
      name: :opacity,
      field: :opacity,
      type: :number,
      render: {:option_method, :opacity, :f32}
    },
    %Style{name: :gap, field: :gap, type: :px, render: {:option_method, :gap, :px}},
    %Style{name: :padding, field: :padding, type: :px, render: {:option_method, :p, :px}},
    %Style{name: :padding_x, field: :padding_x, type: :px, render: {:option_method, :px, :px}},
    %Style{name: :padding_y, field: :padding_y, type: :px, render: {:option_method, :py, :px}},
    %Style{
      name: :padding_top,
      field: :padding_top,
      type: :px,
      render: {:option_method, :pt, :px}
    },
    %Style{
      name: :padding_right,
      field: :padding_right,
      type: :px,
      render: {:option_method, :pr, :px}
    },
    %Style{
      name: :padding_bottom,
      field: :padding_bottom,
      type: :px,
      render: {:option_method, :pb, :px}
    },
    %Style{
      name: :padding_left,
      field: :padding_left,
      type: :px,
      render: {:option_method, :pl, :px}
    },
    %Style{name: :margin, field: :margin, type: :px, render: {:option_method, :m, :px}},
    %Style{name: :margin_x, field: :margin_x, type: :px, render: {:option_method, :mx, :px}},
    %Style{name: :margin_y, field: :margin_y, type: :px, render: {:option_method, :my, :px}},
    %Style{name: :margin_top, field: :margin_top, type: :px, render: {:option_method, :mt, :px}},
    %Style{
      name: :margin_right,
      field: :margin_right,
      type: :px,
      render: {:option_method, :mr, :px}
    },
    %Style{
      name: :margin_bottom,
      field: :margin_bottom,
      type: :px,
      render: {:option_method, :mb, :px}
    },
    %Style{
      name: :margin_left,
      field: :margin_left,
      type: :px,
      render: {:option_method, :ml, :px}
    },
    %Style{name: :width, field: :width, type: :px, render: {:option_method, :w, :px}},
    %Style{name: :height, field: :height, type: :px, render: {:option_method, :h, :px}},
    %Style{name: :min_width, field: :min_width, type: :px, render: {:option_method, :min_w, :px}},
    %Style{name: :max_width, field: :max_width, type: :px, render: {:option_method, :max_w, :px}},
    %Style{
      name: :min_height,
      field: :min_height,
      type: :px,
      render: {:option_method, :min_h, :px}
    },
    %Style{
      name: :max_height,
      field: :max_height,
      type: :px,
      render: {:option_method, :max_h, :px}
    },
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
    },
    %Style{
      name: :border_color,
      field: :border_color,
      type: :rgb,
      render: {:option_method, :border_color, :rgb}
    }
  ]

  @resources [
    %Resource{
      name: :raster,
      fields: [
        width: :u32,
        height: :u32,
        format: {:default, :atom_string, "rgba8"},
        stride: {:option, :u32},
        data: :binary
      ]
    },
    %Resource{
      name: :resource_ref,
      fields: [id: :string, resource_type: {:field, :type, :atom}]
    }
  ]

  def components, do: @components
  def stateful_components, do: Enum.filter(@components, & &1.stateful)
  def styles, do: Enum.map(@styles, & &1.name)
  def style_specs, do: @styles
  def resources, do: Enum.map(@resources, & &1.name)
  def resource_specs, do: @resources
  def tags, do: Enum.map(@components, & &1.tag)

  def identified_tags do
    for %Component{tag: tag, attrs: attrs} <- @components,
        Keyword.has_key?(attrs, :id),
        do: tag
  end

  def events do
    @components
    |> Enum.flat_map(&Keyword.values(&1.events))
    |> Enum.uniq()
  end
end
