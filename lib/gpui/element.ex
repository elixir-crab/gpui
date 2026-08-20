defmodule GPUI.Element do
  @moduledoc """
  Serializable element tree produced by `GPUI.View` modules.
  """

  @type primitive :: String.t() | number() | atom()
  @type child :: t() | primitive()
  @type t :: %__MODULE__{type: atom(), attrs: keyword(), children: [child()]}

  defstruct [:type, attrs: [], children: []]

  @identified_tags MapSet.new(GPUI.Schema.identified_tags())

  @doc "Appends one child to an immutable element value."
  @spec append_child(t(), child()) :: t()
  def append_child(%__MODULE__{} = element, child) do
    %{element | children: element.children ++ [child]}
  end

  @doc "Adds or replaces one explicit style value on an immutable element."
  @spec put_style(t(), atom(), term()) :: t()
  def put_style(%__MODULE__{} = element, key, value) when is_atom(key) do
    styles = Keyword.get(element.attrs, :style, [])
    attrs = Keyword.put(element.attrs, :style, Keyword.put(styles, key, value))
    %{element | attrs: attrs}
  end

  @doc "Converts an element tree into plain serializable maps/lists."
  @spec to_payload(t() | child()) :: map() | String.t()
  def to_payload(%__MODULE__{} = element) do
    validate_component_ids!(element)
    payload(element)
  end

  def to_payload(text) when is_binary(text), do: text
  def to_payload(value) when is_integer(value) or is_float(value) or is_atom(value), do: value

  defp payload(%__MODULE__{} = element) do
    attrs = validated_primitive_attrs(element)

    %{
      type: element.type,
      attrs: attrs |> normalize_class_attr() |> attrs_to_payload(),
      children: Enum.map(element.children, &payload/1)
    }
  end

  defp payload(value), do: to_payload(value)

  defp validated_primitive_attrs(%__MODULE__{type: :layer, children: [_child], attrs: attrs}) do
    attrs
    |> Map.new()
    |> GPUI.Schema.validate_component_assigns!(:layer)
    |> Map.to_list()
  end

  defp validated_primitive_attrs(%__MODULE__{type: :layer}),
    do: raise(ArgumentError, "layer requires exactly one child")

  defp validated_primitive_attrs(%__MODULE__{type: :text_surface, attrs: attrs}) do
    attrs
    |> Map.new()
    |> GPUI.Schema.validate_component_assigns!(:text_surface)
    |> Map.to_list()
  end

  defp validated_primitive_attrs(%__MODULE__{type: type, attrs: attrs})
       when type in [:div, :button, :span, :scroll, :list, :item, :input] do
    attrs_map = Map.new(attrs)
    observed? = Map.has_key?(attrs_map, :"phx-bounds-change")

    focused? =
      Map.get(attrs_map, :focus_request, 0) > 0 or
        Map.has_key?(attrs_map, :"phx-focus") or Map.has_key?(attrs_map, :"phx-blur")

    motion? = Map.get(attrs_map, :motion_request, 0) > 0
    declarative_feature? = motion_attrs?(attrs_map) or Map.has_key?(attrs_map, :window_control)
    accessible? = GPUI.Accessibility.metadata?(attrs_map)

    validate_interactive_feature_id!(type, attrs_map, observed?, focused?, motion?)

    if observed? or focused? or declarative_feature? or accessible? do
      attrs_map
      |> GPUI.Schema.validate_component_assigns!(type)
      |> then(&GPUI.Accessibility.validate_generic!(type, &1))
      |> Map.to_list()
    else
      attrs
    end
  end

  defp validated_primitive_attrs(%__MODULE__{attrs: attrs}), do: attrs

  defp motion_attrs?(attrs) do
    Enum.any?(Map.keys(attrs), &String.starts_with?(Atom.to_string(&1), "motion_"))
  end

  defp validate_interactive_feature_id!(_type, _attrs, false, false, false), do: :ok

  defp validate_interactive_feature_id!(type, attrs, observed?, _focused?, motion?),
    do: validate_feature_id!(type, attrs, observed?, motion?)

  defp validate_feature_id!(type, attrs, observed?, motion?) do
    unless is_binary(Map.get(attrs, :id)) and Map.get(attrs, :id) != "" do
      feature =
        cond do
          observed? -> "phx-bounds-change"
          motion? -> "motion_request"
          true -> "focus behavior"
        end

      raise ArgumentError, "#{type} with #{feature} requires a non-empty string id"
    end
  end

  defp normalize_class_attr(attrs) do
    case Keyword.fetch(attrs, :class) do
      {:ok, class} when is_binary(class) ->
        %{style: class_style, unknown: unknown} = GPUI.Tailwind.normalize(class)
        style = merge_styles(class_style, Keyword.get(attrs, :style, []))

        attrs
        |> Keyword.delete(:class)
        |> put_attr(:style, style, style != [])
        |> put_attr(:class, Enum.join(unknown, " "), unknown != [])

      _other ->
        attrs
    end
  end

  defp merge_styles(class_style, style) when is_list(style), do: Keyword.merge(class_style, style)

  defp merge_styles(class_style, style) when is_map(style),
    do: class_style |> Map.new() |> Map.merge(style) |> Map.to_list()

  defp put_attr(attrs, _key, _value, false), do: attrs
  defp put_attr(attrs, key, value, true), do: Keyword.put(attrs, key, value)

  defp validate_component_ids!(element) do
    element
    |> collect_component_ids(MapSet.new())
    |> then(fn _ids -> :ok end)
  end

  defp collect_component_ids(%__MODULE__{} = element, ids) do
    ids =
      if MapSet.member?(@identified_tags, element.type) do
        id = Keyword.get(element.attrs, :id)

        unless is_binary(id) and id != "" do
          raise ArgumentError, "#{element.type} requires a non-empty string id"
        end

        if MapSet.member?(ids, id) do
          raise ArgumentError, "duplicate GPUI component id #{inspect(id)}"
        end

        MapSet.put(ids, id)
      else
        ids
      end

    Enum.reduce(element.children, ids, &collect_component_ids/2)
  end

  defp collect_component_ids(_primitive, ids), do: ids

  defp attrs_to_payload(attrs) do
    attrs
    |> Enum.map(fn
      {:accessibility_checked, value} ->
        {:accessibility_checked, accessibility_checked_to_payload(value)}

      {key, value} ->
        {key, attr_value_to_payload(value)}
    end)
    |> Map.new()
  end

  defp accessibility_checked_to_payload(true), do: "true"
  defp accessibility_checked_to_payload(false), do: "false"
  defp accessibility_checked_to_payload(:mixed), do: "mixed"

  defp attr_value_to_payload(%GPUI.Raster{} = raster), do: GPUI.Raster.to_payload(raster)
  defp attr_value_to_payload(%GPUI.ResourceRef{} = ref), do: GPUI.ResourceRef.to_payload(ref)
  defp attr_value_to_payload(%GPUI.Text.Buffer{ref: ref}), do: ref
  defp attr_value_to_payload(%GPUI.Text.Position{} = position), do: Map.from_struct(position)
  defp attr_value_to_payload(%GPUI.Text.Range{} = range), do: map_struct_values(range)

  defp attr_value_to_payload(%GPUI.Text.InlineProjection{} = projection),
    do: map_struct_values(projection)

  defp attr_value_to_payload(%GPUI.Text.BlockProjection{} = projection) do
    projection
    |> Map.from_struct()
    |> Map.update!(:placement, &Atom.to_string/1)
    |> Map.new(fn {key, value} -> {key, attr_value_to_payload(value)} end)
  end

  defp attr_value_to_payload(%GPUI.Text.RichRun{} = run) do
    run
    |> Map.from_struct()
    |> Map.new(fn
      {key, value}
      when key in [:font_weight, :font_style, :underline_style] and not is_nil(value) and
             is_atom(value) ->
        {key, Atom.to_string(value)}

      {key, value} ->
        {key, attr_value_to_payload(value)}
    end)
  end

  defp attr_value_to_payload(%GPUI.Text.StyleRun{} = run) do
    run
    |> Map.from_struct()
    |> Map.new(fn
      {key, value} when key in [:font_weight, :font_style] and is_atom(value) ->
        {key, Atom.to_string(value)}

      {key, value} ->
        {key, attr_value_to_payload(value)}
    end)
  end

  defp attr_value_to_payload(%GPUI.Text.Decoration{} = decoration) do
    decoration
    |> Map.from_struct()
    |> Map.update!(:underline_style, &Atom.to_string/1)
    |> Map.new(fn {key, value} -> {key, attr_value_to_payload(value)} end)
  end

  defp attr_value_to_payload(value) when is_list(value) do
    Enum.map(value, fn
      {key, item} -> {key, attr_value_to_payload(item)}
      item -> attr_value_to_payload(item)
    end)
  end

  defp attr_value_to_payload(value) when is_tuple(value), do: Tuple.to_list(value)
  defp attr_value_to_payload(value), do: value

  defp map_struct_values(struct) do
    struct
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {key, attr_value_to_payload(value)} end)
  end
end
