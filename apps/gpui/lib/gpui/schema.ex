defmodule GPUI.Schema do
  @moduledoc "Canonical element, component, event, resource, and style protocol schema."

  alias GPUI.Schema.Component
  alias GPUI.Schema.Component.Docs
  alias GPUI.Schema.Extension
  alias GPUI.Schema.Resource
  alias GPUI.Schema.Registry
  alias GPUI.Schema.Style

  Code.ensure_compiled!(Docs)
  Code.ensure_compiled!(Extension)

  @max_text_surface_lines 64
  @max_block_projections 64
  @max_text_ranges 64

  @components GPUI.Schema.Core.components() ++ GPUI.Schema.Surfaces.components()
  @styles [
    %Style{
      name: :display,
      field: :display,
      type: :atom_string,
      render:
        {:enum_methods, [{"flex", :flex}, {"block", :block}, {"grid", :grid}, {"none", :hidden}]}
    },
    %Style{
      name: :position,
      field: :position,
      type: :atom_string,
      render: {:enum_methods, [{"relative", :relative}, {"absolute", :absolute}]}
    },
    %Style{
      name: :inset,
      field: :inset,
      type: :position_length,
      render: {:option_methods, [:top, :right, :bottom, :left], :position_length}
    },
    %Style{
      name: :inset_x,
      field: :inset_x,
      type: :position_length,
      render: {:option_methods, [:left, :right], :position_length}
    },
    %Style{
      name: :inset_y,
      field: :inset_y,
      type: :position_length,
      render: {:option_methods, [:top, :bottom], :position_length}
    },
    %Style{
      name: :top,
      field: :top,
      type: :position_length,
      render: {:option_method, :top, :position_length}
    },
    %Style{
      name: :right,
      field: :right,
      type: :position_length,
      render: {:option_method, :right, :position_length}
    },
    %Style{
      name: :bottom,
      field: :bottom,
      type: :position_length,
      render: {:option_method, :bottom, :position_length}
    },
    %Style{
      name: :left,
      field: :left,
      type: :position_length,
      render: {:option_method, :left, :position_length}
    },
    %Style{
      name: :flex,
      field: :flex,
      type: :atom_string,
      render:
        {:enum_methods,
         [
           {"one", :flex_1},
           {"auto", :flex_auto},
           {"initial", :flex_initial},
           {"none", :flex_none}
         ]}
    },
    %Style{
      name: :flex_basis,
      field: :flex_basis,
      type: :flex_basis,
      render: {:option_method, :flex_basis, :flex_basis}
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
      name: :overflow,
      field: :overflow,
      type: :atom_string,
      render: {:enum_methods, [{"hidden", :overflow_hidden}]}
    },
    %Style{
      name: :white_space,
      field: :white_space,
      type: :atom_string,
      render: {:enum_methods, [{"normal", :whitespace_normal}, {"nowrap", :whitespace_nowrap}]}
    },
    %Style{
      name: :text_overflow,
      field: :text_overflow,
      type: :atom_string,
      render: {:enum_methods, [{"ellipsis", :text_ellipsis}]}
    },
    %Style{
      name: :text_align,
      field: :text_align,
      type: :atom_string,
      render:
        {:enum_methods, [{"left", :text_left}, {"center", :text_center}, {"right", :text_right}]}
    },
    %Style{name: :truncate, field: :truncate, type: {:atom_eq, true}, render: :truncate_if_true},
    %Style{
      name: :cursor,
      field: :cursor,
      type: :atom_string,
      render:
        {:enum_methods,
         [
           {"default", :cursor_default},
           {"pointer", :cursor_pointer},
           {"text", :cursor_text},
           {"move", :cursor_move},
           {"not_allowed", :cursor_not_allowed}
         ]}
    },
    %Style{
      name: :background,
      field: :background,
      type: :color,
      render: {:option_method, :bg, :color}
    },
    %Style{
      name: :color,
      field: :color,
      type: :color,
      render: {:option_method, :text_color, :color}
    },
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
    %Style{name: :width, field: :width, type: :length, render: {:option_method, :w, :length}},
    %Style{name: :height, field: :height, type: :length, render: {:option_method, :h, :length}},
    %Style{
      name: :min_width,
      field: :min_width,
      type: :length,
      render: {:option_method, :min_w, :length}
    },
    %Style{
      name: :max_width,
      field: :max_width,
      type: :length,
      render: {:option_method, :max_w, :length}
    },
    %Style{
      name: :min_height,
      field: :min_height,
      type: :length,
      render: {:option_method, :min_h, :length}
    },
    %Style{
      name: :max_height,
      field: :max_height,
      type: :length,
      render: {:option_method, :max_h, :length}
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
      type: :color,
      render: {:option_method, :border_color, :color}
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

  @extensions @components
              |> Enum.flat_map(fn
                %Component{extension: %Extension{} = extension} -> [extension]
                _component -> []
              end)

  extension_keys = Enum.map(@extensions, &{&1.id, &1.version})

  if Enum.uniq(extension_keys) != extension_keys do
    raise ArgumentError, "extension IDs and versions must be unique"
  end

  max_extension_capabilities = Extension.max_capabilities()

  Enum.each(@extensions, fn extension ->
    unless is_atom(extension.id) and is_integer(extension.version) and extension.version > 0 and
             is_list(extension.capabilities) and
             Enum.count_until(extension.capabilities, max_extension_capabilities + 1) <=
               max_extension_capabilities and
             Enum.all?(extension.capabilities, &is_atom/1) and
             Enum.uniq(extension.capabilities) == extension.capabilities do
      raise ArgumentError, "invalid extension contract: #{inspect(extension)}"
    end
  end)

  def components, do: @components

  @doc "Returns an immutable registry containing neutral core declarations."
  @spec registry() :: Registry.t()
  def registry do
    Registry.new()
    |> Registry.include(GPUI.Schema.Core)
  end

  @doc "Returns a composed registry for explicitly selected schema modules."
  @spec registry([module()]) :: Registry.t()
  def registry(modules) when is_list(modules) do
    Enum.reduce(modules, Registry.new(), &Registry.include(&2, &1))
  end

  @doc "Returns generated public option documentation for a component tag."
  @spec component_options_doc(atom()) :: String.t()
  def component_options_doc(tag), do: tag |> component!() |> Docs.options_doc()

  @doc "Defines public component option types from schema definitions."
  defmacro define_component_option_types(definitions) do
    definitions = Macro.expand(definitions, __CALLER__)

    types =
      Enum.map(definitions, fn {type_name, tag} ->
        type = tag |> component!() |> Docs.option_type_ast()
        builder = type_name |> Atom.to_string() |> String.trim_trailing("_options")

        quote do
          @typedoc "Options accepted by `#{unquote(builder)}/1`."
          @type unquote({type_name, [], []}) :: unquote(type)
        end
      end)

    quote do
      (unquote_splicing(types))
    end
  end

  def component!(tag) do
    Enum.find(@components, &(&1.tag == tag)) ||
      raise ArgumentError, "unknown GPUI component #{inspect(tag)}"
  end

  def defaults(tag) do
    tag
    |> component!()
    |> Map.fetch!(:attrs)
    |> Enum.reduce(%{}, fn
      {name, {:default, _type, value}}, defaults -> Map.put(defaults, name, value)
      {name, :boolean}, defaults -> Map.merge(defaults, Map.new([{name, false}]))
      {name, :string_list}, defaults -> Map.put(defaults, name, [])
      {_name, _type}, defaults -> defaults
    end)
  end

  def apply_defaults(assigns, tag) when is_map(assigns) do
    defaults(tag)
    |> Map.merge(assigns)
  end

  @spec validate_component_assigns!(map(), atom() | Component.t(), [atom()]) :: map()
  def validate_component_assigns!(assigns, tag_or_component, extra_attrs \\ [])

  def validate_component_assigns!(assigns, tag, extra_attrs)
      when is_map(assigns) and is_atom(tag) and is_list(extra_attrs) do
    validate_component_assigns!(assigns, component!(tag), extra_attrs)
  end

  def validate_component_assigns!(assigns, %Component{} = component, extra_attrs)
      when is_map(assigns) and is_list(extra_attrs) do
    assigns = normalize_event_keys!(assigns, component)
    validate_known_attrs!(assigns, component, extra_attrs)
    validate_declared_attrs!(assigns, component)
    validate_component_contract!(assigns, component.tag)
    validate_events!(assigns, component)
    validate_required_events!(assigns, component)
    assigns
  end

  defp validate_declared_attrs!(assigns, component) do
    Enum.each(component.attrs, fn {name, type} ->
      case {type, Map.fetch(assigns, name)} do
        {:required_string, {:ok, value}} ->
          validate_attr!(component.tag, name, type, value)

        {:required_string, _missing} ->
          invalid_attr!(component.tag, name, "a non-empty string", nil)

        {_type, {:ok, value}} when not is_nil(value) ->
          validate_attr!(component.tag, name, type, value)

        {_type, _missing_or_nil} ->
          :ok
      end
    end)
  end

  defp validate_component_contract!(assigns, :text_surface) do
    min_lines = Map.get(assigns, :min_lines, 1)
    max_lines = Map.get(assigns, :max_lines, 8)
    submit_policy = Map.get(assigns, :submit_policy, "newline")
    submit_event = Map.get(assigns, :"phx-submit")

    validate_text_surface_line_bounds!(min_lines, max_lines)
    validate_text_surface_submit!(submit_policy, submit_event)
    assigns
  end

  defp validate_component_contract!(assigns, tag)
       when tag in [:div, :button, :span, :scroll, :list, :item] do
    request = Map.get(assigns, :motion_request, 0)
    duration = Map.get(assigns, :motion_duration, 180)
    delay = Map.get(assigns, :motion_delay, 0)
    opacity = Map.get(assigns, :motion_from_opacity, 1.0)
    x = Map.get(assigns, :motion_from_x, 0.0)
    y = Map.get(assigns, :motion_from_y, 0.0)

    if request > 0 and not (is_binary(Map.get(assigns, :id)) and Map.get(assigns, :id) != "") do
      raise ArgumentError, "#{tag} with motion_request requires a non-empty string id"
    end

    validate_motion_bound!(tag, :motion_duration, duration, 10_000)
    validate_motion_bound!(tag, :motion_delay, delay, 10_000)

    unless is_number(opacity) and opacity >= 0.0 and opacity <= 1.0 do
      invalid_attr!(tag, :motion_from_opacity, "a number from 0.0 through 1.0", opacity)
    end

    validate_motion_offset!(tag, :motion_from_x, x)
    validate_motion_offset!(tag, :motion_from_y, y)
    assigns
  end

  defp validate_component_contract!(assigns, _tag), do: assigns

  defp validate_motion_bound!(tag, name, value, max) do
    if is_integer(value) and value <= max,
      do: :ok,
      else: invalid_attr!(tag, name, "an integer no greater than #{max}", value)
  end

  defp validate_motion_offset!(tag, name, value) do
    if is_number(value) and value >= -4_096 and value <= 4_096,
      do: :ok,
      else: invalid_attr!(tag, name, "a number from -4096 through 4096", value)
  end

  defp validate_text_surface_line_bounds!(min_lines, max_lines) do
    if is_integer(min_lines) and min_lines > @max_text_surface_lines do
      raise ArgumentError,
            "text_surface min_lines must be at most #{@max_text_surface_lines}, got: #{inspect(min_lines)}"
    end

    if is_integer(max_lines) and max_lines > @max_text_surface_lines do
      raise ArgumentError,
            "text_surface max_lines must be at most #{@max_text_surface_lines}, got: #{inspect(max_lines)}"
    end

    if is_integer(min_lines) and is_integer(max_lines) and min_lines > max_lines do
      raise ArgumentError,
            "text_surface min_lines must be less than or equal to max_lines, got: #{inspect(min_lines)} > #{inspect(max_lines)}"
    end
  end

  defp validate_text_surface_submit!("submit", event)
       when not (is_binary(event) and event != "") do
    raise ArgumentError,
          "text_surface with submit_policy=\"submit\" requires a non-empty phx-submit event"
  end

  defp validate_text_surface_submit!(_policy, _event), do: :ok

  defp validate_events!(assigns, component) do
    Enum.each(component.events, fn {_event, name} ->
      case Map.fetch(assigns, name) do
        {:ok, value} when is_binary(value) and value != "" -> :ok
        {:ok, nil} -> :ok
        :error -> :ok
        {:ok, value} -> invalid_attr!(component.tag, name, "a non-empty string", value)
      end
    end)
  end

  defp validate_required_events!(assigns, component) do
    Enum.each(component.required_events, fn name ->
      value = Map.get(assigns, name)

      unless is_binary(value) and value != "" do
        invalid_attr!(component.tag, name, "a non-empty string", value)
      end
    end)
  end

  defp normalize_event_keys!(assigns, component) do
    Enum.reduce(component.events, assigns, fn {_event, name}, normalized ->
      string_name = Atom.to_string(name)

      case {Map.fetch(normalized, name), Map.fetch(normalized, string_name)} do
        {{:ok, _atom_value}, {:ok, _string_value}} ->
          raise ArgumentError,
                "#{component.tag} received duplicate :#{name} and #{inspect(string_name)} attributes"

        {:error, {:ok, value}} ->
          normalized |> Map.delete(string_name) |> Map.put(name, value)

        _other ->
          normalized
      end
    end)
  end

  defp validate_known_attrs!(assigns, component, extra_attrs) do
    allowed =
      component.attrs
      |> Keyword.keys()
      |> Kernel.++(Keyword.values(component.events))
      |> Kernel.++([:children, :class, :style | extra_attrs])
      |> MapSet.new()

    unknown = assigns |> Map.keys() |> Enum.reject(&MapSet.member?(allowed, &1))

    if unknown != [] do
      names = unknown |> Enum.sort_by(&inspect/1) |> Enum.map_join(", ", &inspect/1)
      raise ArgumentError, "#{component.tag} received unsupported attributes: #{names}"
    end
  end

  defp validate_attr!(tag, name, {:default, type}, value),
    do: validate_attr!(tag, name, type, value)

  defp validate_attr!(tag, name, {:default, type, _default}, value),
    do: validate_attr!(tag, name, type, value)

  defp validate_attr!(_tag, _name, :string, value) when is_binary(value), do: :ok

  defp validate_attr!(_tag, _name, :accessibility_label, value)
       when is_binary(value) and value != "" and byte_size(value) <= 512,
       do: :ok

  defp validate_attr!(_tag, _name, :accessibility_description, value)
       when is_binary(value) and value != "" and byte_size(value) <= 2048,
       do: :ok

  defp validate_attr!(_tag, _name, :accessibility_value, value)
       when is_binary(value) and value != "" and byte_size(value) <= 512,
       do: :ok

  defp validate_attr!(_tag, _name, :accessibility_checked, :mixed), do: :ok

  defp validate_attr!(_tag, _name, :accessibility_checked, value) when is_boolean(value),
    do: :ok

  defp validate_attr!(_tag, _name, :required_string, value)
       when is_binary(value) and value != "",
       do: :ok

  defp validate_attr!(_tag, _name, :number, value) when is_number(value), do: :ok

  defp validate_attr!(_tag, _name, :non_negative_number, value)
       when is_number(value) and value >= 0,
       do: :ok

  defp validate_attr!(_tag, _name, :positive_number, value) when is_number(value) and value > 0,
    do: :ok

  defp validate_attr!(_tag, _name, :unit_number, value)
       when is_number(value) and value >= 0 and value <= 1,
       do: :ok

  defp validate_attr!(_tag, _name, :edge_fade_size, value)
       when is_number(value) and value >= 1 and value <= 256,
       do: :ok

  defp validate_attr!(_tag, _name, :non_negative_integer, value)
       when is_integer(value) and value >= 0, do: :ok

  defp validate_attr!(_tag, _name, :layer_priority, value)
       when is_integer(value) and value in 0..1024,
       do: :ok

  defp validate_attr!(_tag, _name, :positive_integer, value) when is_integer(value) and value > 0,
    do: :ok

  defp validate_attr!(_tag, _name, :boolean, value) when is_boolean(value), do: :ok

  defp validate_attr!(_tag, _name, :number_pair, [first, second])
       when is_number(first) and is_number(second),
       do: :ok

  defp validate_attr!(tag, name, :number_pair, value),
    do: invalid_attr!(tag, name, "a list of exactly two numbers", value)

  defp validate_attr!(tag, name, :string_list, value) when is_list(value) do
    if Enum.all?(value, &is_binary/1),
      do: :ok,
      else: invalid_attr!(tag, name, "a list of strings", value)
  end

  defp validate_attr!(tag, name, {:enum_list, values}, value) when is_list(value) do
    normalized = Enum.map(value, &to_string/1)

    if length(normalized) <= length(values) and normalized == Enum.uniq(normalized) and
         Enum.all?(normalized, &(&1 in values)) do
      :ok
    else
      invalid_attr!(tag, name, "a unique list drawn from #{inspect(values)}", value)
    end
  end

  defp validate_attr!(tag, name, :paint_commands, value) when is_list(value) do
    valid? = Enum.count_until(value, 257) <= 256 and Enum.all?(value, &valid_paint_command?/1)

    if valid?,
      do: :ok,
      else: invalid_attr!(tag, name, "at most 256 bounded paint commands", value)
  end

  defp validate_attr!(_tag, _name, type, value)
       when type in [:select_options, :radio_options] and is_list(value),
       do: :ok

  defp validate_attr!(_tag, _name, :resource, value) when is_map(value), do: :ok

  defp validate_attr!(_tag, _name, :text_buffer, %{__struct__: GPUI.Text.Buffer, ref: ref})
       when is_reference(ref),
       do: :ok

  defp validate_attr!(_tag, _name, :text_position, %{__struct__: GPUI.Text.Position}), do: :ok

  defp validate_attr!(tag, name, :text_block_projections, value) when is_list(value) do
    valid? =
      Enum.count_until(value, @max_block_projections + 1) <= @max_block_projections and
        Enum.all?(value, &valid_block_projection?/1)

    if valid?,
      do: :ok,
      else:
        invalid_attr!(
          tag,
          name,
          "at most #{@max_block_projections} bounded GPUI.Text.BlockProjection values",
          value
        )
  end

  defp validate_attr!(tag, name, :text_inline_projections, value) when is_list(value) do
    valid? =
      Enum.count_until(value, 129) <= 128 and
        Enum.all?(value, fn
          %{
            __struct__: GPUI.Text.InlineProjection,
            position: %{__struct__: GPUI.Text.Position}
          } = projection ->
            GPUI.Text.InlineProjection.validate!(projection)
            true

          _other ->
            false
        end)

    if valid?,
      do: :ok,
      else:
        invalid_attr!(tag, name, "at most 128 bounded GPUI.Text.InlineProjection values", value)
  end

  defp validate_attr!(tag, name, :rich_text_runs, value) when is_list(value) do
    if Enum.count_until(value, 2_049) <= 2_048 and
         Enum.all?(value, &match?(%GPUI.Text.RichRun{}, &1)) do
      :ok
    else
      invalid_attr!(tag, name, "at most 2048 GPUI.Text.RichRun values", value)
    end
  end

  defp validate_attr!(tag, name, :text_style_runs, value) when is_list(value) do
    valid? = Enum.count_until(value, 513) <= 512 and Enum.all?(value, &valid_style_run?/1)

    if valid?,
      do: :ok,
      else: invalid_attr!(tag, name, "at most 512 bounded GPUI.Text.StyleRun values", value)
  end

  defp validate_attr!(tag, name, :text_decorations, value) when is_list(value) do
    valid? =
      Enum.count_until(value, 257) <= 256 and
        Enum.all?(value, fn
          %{__struct__: GPUI.Text.Decoration, range: %{__struct__: GPUI.Text.Range}} = decoration ->
            GPUI.Text.Decoration.validate!(decoration)
            true

          _other ->
            false
        end)

    if valid?,
      do: :ok,
      else: invalid_attr!(tag, name, "at most 256 GPUI.Text.Decoration values", value)
  end

  defp validate_attr!(tag, name, :text_ranges, value) when is_list(value) do
    if Enum.count_until(value, @max_text_ranges + 1) <= @max_text_ranges and
         Enum.all?(value, &match?(%{__struct__: GPUI.Text.Range}, &1)) do
      :ok
    else
      invalid_attr!(tag, name, "at most #{@max_text_ranges} GPUI.Text.Range values", value)
    end
  end

  defp validate_attr!(tag, name, {:enum, values}, value) do
    if value in values,
      do: :ok,
      else: invalid_attr!(tag, name, "one of #{Enum.map_join(values, ", ", &inspect/1)}", value)
  end

  defp validate_attr!(tag, name, type, value),
    do: invalid_attr!(tag, name, expected_attr_type(type), value)

  defp valid_style_run?(
         %{
           __struct__: GPUI.Text.StyleRun,
           range: %{__struct__: GPUI.Text.Range}
         } = run
       ) do
    GPUI.Text.StyleRun.validate!(run)
    true
  end

  defp valid_style_run?(_other), do: false

  defp valid_block_projection?(
         %{
           __struct__: GPUI.Text.BlockProjection
         } = block
       ) do
    GPUI.Text.BlockProjection.validate!(block)
    true
  end

  defp valid_block_projection?(_other), do: false

  defp valid_paint_command?(%{type: type, x: x, y: y, width: width, height: height, color: color})
       when type in [:rect, "rect"] do
    paint_coordinate?(x) and paint_coordinate?(y) and paint_size?(width) and paint_size?(height) and
      valid_rgba?(color)
  end

  defp valid_paint_command?(%{
         type: type,
         x1: x1,
         y1: y1,
         x2: x2,
         y2: y2,
         width: width,
         color: color
       })
       when type in [:line, "line"] do
    Enum.all?([x1, y1, x2, y2], &paint_coordinate?/1) and is_number(width) and width > 0 and
      width <= 256 and valid_rgba?(color)
  end

  defp valid_paint_command?(_command), do: false

  defp paint_coordinate?(value),
    do: is_number(value) and value >= -1_000_000 and value <= 1_000_000

  defp paint_size?(value), do: is_number(value) and value >= 0 and value <= 1_000_000
  defp valid_rgba?(color), do: is_integer(color) and color in 0..0xFFFFFFFF

  defp expected_attr_type(:string), do: "a string"

  defp expected_attr_type(:accessibility_label),
    do: "a non-empty string of at most 512 bytes"

  defp expected_attr_type(:accessibility_description),
    do: "a non-empty string of at most 2048 bytes"

  defp expected_attr_type(:accessibility_value),
    do: "a non-empty string of at most 512 bytes"

  defp expected_attr_type(:accessibility_checked), do: "true, false, or :mixed"

  defp expected_attr_type(:required_string), do: "a non-empty string"
  defp expected_attr_type(:number), do: "a number"
  defp expected_attr_type(:non_negative_number), do: "a non-negative number"
  defp expected_attr_type(:positive_number), do: "a number greater than zero"
  defp expected_attr_type(:unit_number), do: "a number from zero through one"
  defp expected_attr_type(:edge_fade_size), do: "a number from 1 through 256"
  defp expected_attr_type(:layer_priority), do: "an integer from 0 through 1024"
  defp expected_attr_type(:non_negative_integer), do: "a non-negative integer"
  defp expected_attr_type(:positive_integer), do: "an integer greater than zero"
  defp expected_attr_type(:boolean), do: "a boolean"
  defp expected_attr_type(:string_list), do: "a list of strings"
  defp expected_attr_type({:enum_list, values}), do: "a unique list drawn from #{inspect(values)}"

  defp expected_attr_type(type) when type in [:select_options, :radio_options],
    do: "an options list"

  defp expected_attr_type(:resource), do: "a resource map"
  defp expected_attr_type(:text_buffer), do: "a GPUI.Text.Buffer"

  defp expected_attr_type(:text_ranges),
    do: "at most #{@max_text_ranges} GPUI.Text.Range values"

  defp expected_attr_type(:text_position), do: "a GPUI.Text.Position"
  defp expected_attr_type(:rich_text_runs), do: "at most 2048 GPUI.Text.RichRun values"

  defp expected_attr_type(:text_decorations), do: "at most 256 GPUI.Text.Decoration values"
  defp expected_attr_type(:text_style_runs), do: "at most 512 bounded GPUI.Text.StyleRun values"

  defp expected_attr_type(:text_inline_projections),
    do: "at most 128 bounded GPUI.Text.InlineProjection values"

  defp expected_attr_type(:text_block_projections),
    do: "at most #{@max_block_projections} bounded GPUI.Text.BlockProjection values"

  defp expected_attr_type(:paint_commands), do: "at most 256 bounded paint commands"

  defp invalid_attr!(tag, name, expected, value) do
    raise ArgumentError,
          "#{tag} :#{name} must be #{expected}; got: #{inspect(value)}"
  end

  @doc "Returns all schema-owned versioned presentation contracts."
  @spec extensions() :: [Extension.t()]
  def extensions, do: @extensions

  @doc "Returns one schema-owned presentation contract by ID."
  @spec extension(atom()) :: Extension.t()
  def extension(id) when is_atom(id) do
    Enum.find(@extensions, &(&1.id == id)) ||
      raise ArgumentError, "unknown GPUI extension #{inspect(id)}"
  end

  def stateful_components, do: Enum.filter(@components, & &1.stateful)
  def styles, do: Enum.map(@styles, & &1.name)
  def style_specs, do: @styles
  def resources, do: Enum.map(@resources, & &1.name)
  def resource_specs, do: @resources

  def tags do
    @components
    |> Enum.reject(&Component.renderer_internal?/1)
    |> Enum.map(& &1.tag)
  end

  @doc "Returns every renderer-native schema tag in declaration order."
  def native_tags, do: Enum.map(@components, & &1.tag)

  def identified_tags do
    for %Component{tag: tag, attrs: attrs} <- @components,
        Keyword.has_key?(attrs, :id),
        tag not in [:div, :button, :span, :scroll, :list, :item, :text_input],
        do: tag
  end

  def events do
    @components
    |> Enum.flat_map(&Keyword.values(&1.events))
    |> Enum.uniq()
  end
end
