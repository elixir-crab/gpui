defmodule GPUI.Element do
  @moduledoc """
  Serializable element tree produced by `GPUI.View` modules.
  """

  @type primitive :: String.t() | number() | atom()
  @type child :: t() | primitive()
  @type t :: %__MODULE__{type: atom(), attrs: keyword(), children: [child()]}

  defstruct [:type, attrs: [], children: []]

  @identified_tags MapSet.new(GPUI.Schema.identified_tags())

  @doc false
  @spec append_child(t(), child()) :: t()
  def append_child(%__MODULE__{} = element, child) do
    %{element | children: element.children ++ [child]}
  end

  @doc false
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
    %{
      type: element.type,
      attrs: attrs_to_payload(element.attrs),
      children: Enum.map(element.children, &payload/1)
    }
  end

  defp payload(value), do: to_payload(value)

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
    |> Enum.map(fn {key, value} -> {key, attr_value_to_payload(value)} end)
    |> Map.new()
  end

  defp attr_value_to_payload(%GPUI.Raster{} = raster), do: GPUI.Raster.to_payload(raster)
  defp attr_value_to_payload(%GPUI.ResourceRef{} = ref), do: GPUI.ResourceRef.to_payload(ref)

  defp attr_value_to_payload(value) when is_list(value) do
    Enum.map(value, fn
      {key, item} -> {key, attr_value_to_payload(item)}
      item -> attr_value_to_payload(item)
    end)
  end

  defp attr_value_to_payload(value) when is_tuple(value), do: Tuple.to_list(value)
  defp attr_value_to_payload(value), do: value
end
