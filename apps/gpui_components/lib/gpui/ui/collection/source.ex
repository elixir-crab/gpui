defmodule GPUI.UI.Collection.Source do
  @moduledoc """
  Cohesive source-backed collection window.

  A source window pairs the total logical item count with the offset and loaded
  child slice currently present in the snapshot. `assigns/1` converts it to the
  ordinary options accepted by `GPUI.UI.virtual_list/1`, `data_table/1`, and
  `tree/1`.
  """

  @enforce_keys [:total_count, :offset, :items]
  defstruct [:total_count, :offset, :items]

  @type t :: %__MODULE__{
          total_count: non_neg_integer(),
          offset: non_neg_integer(),
          items: [GPUI.Element.child()]
        }

  @doc "Builds and validates a loaded source-backed collection window."
  @spec new(non_neg_integer(), non_neg_integer(), [GPUI.Element.child()]) :: t()
  def new(total_count, offset, items)
      when is_integer(total_count) and total_count >= 0 and is_integer(offset) and offset >= 0 and
             is_list(items) do
    if offset + length(items) <= total_count do
      %__MODULE__{total_count: total_count, offset: offset, items: items}
    else
      raise ArgumentError, "collection source slice must fit within total_count"
    end
  end

  @doc "Returns component assigns for a source-backed collection window."
  @spec assigns(t()) :: map()
  def assigns(%__MODULE__{} = source) do
    %{total_count: source.total_count, offset: source.offset, children: source.items}
  end
end
