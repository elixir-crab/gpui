defmodule GPUI.Text.CaretGeometry do
  @moduledoc """
  Window-relative native pixel bounds for a text surface's primary caret.

  The logical position uses zero-based UTF-16 line coordinates. Bounds are
  reported only while the caret is part of the currently laid-out viewport.
  """

  @enforce_keys [:line, :utf16_offset, :x, :y, :width, :height]
  defstruct [:line, :utf16_offset, :x, :y, :width, :height]

  @type t :: %__MODULE__{
          line: non_neg_integer(),
          utf16_offset: non_neg_integer(),
          x: float(),
          y: float(),
          width: float(),
          height: float()
        }

  @doc "Decodes a protocol caret-geometry map into a typed value."
  @spec from_event(map()) :: t()
  def from_event(value) when is_map(value) do
    struct!(__MODULE__, value)
  end
end
