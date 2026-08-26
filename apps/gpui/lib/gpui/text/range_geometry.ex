defmodule GPUI.Text.RangeGeometry do
  @moduledoc """
  Window-relative native pixel bounds for one requested logical text range.

  Range geometry is bounded to at most 64 requests per surface and includes
  only ranges present in the current native layout. Each result contains a
  bounded rectangle for every visual row crossed by wrapped text.
  """

  alias GPUI.Text.{Position, Range, Rectangle}

  @enforce_keys [:range, :rectangles]
  defstruct [:range, :rectangles]

  @type t :: %__MODULE__{
          range: Range.t(),
          rectangles: [Rectangle.t()]
        }

  @doc "Decodes a protocol range-geometry map into a typed value."
  @spec from_event(map()) :: t()
  def from_event(%{range: %{start: start_position, end: end_position}} = value) do
    range = %Range{start: struct!(Position, start_position), end: struct!(Position, end_position)}
    rectangles = Enum.map(value.rectangles, &Rectangle.from_event/1)
    struct!(__MODULE__, %{value | range: range, rectangles: rectangles})
  end
end
