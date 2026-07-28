defmodule GPUI.Text.RangeGeometry do
  @moduledoc """
  Window-relative native pixel bounds for one requested logical text range.

  Range geometry is bounded to at most 64 requests per surface and includes
  only ranges present in the current native layout. Wrapped ranges may span a
  taller bounding rectangle; per-visual-row rectangles are a later contract.
  """

  alias GPUI.Text.{Position, Range}

  @enforce_keys [:range, :x, :y, :width, :height]
  defstruct [:range, :x, :y, :width, :height]

  @type t :: %__MODULE__{
          range: Range.t(),
          x: float(),
          y: float(),
          width: float(),
          height: float()
        }

  @doc false
  @spec from_event(map()) :: t()
  def from_event(%{range: %{start: start_position, end: end_position}} = value) do
    range = %Range{start: struct!(Position, start_position), end: struct!(Position, end_position)}
    struct!(__MODULE__, %{value | range: range})
  end
end
