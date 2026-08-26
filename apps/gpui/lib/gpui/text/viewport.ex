defmodule GPUI.Text.Viewport do
  @moduledoc """
  A revision-tagged snapshot of one text surface's visible visual rows.

  Scroll coordinates are native GPUI pixels relative to the surface's laid-out
  text viewport. Offsets are typically zero or negative as content moves above
  or to the left of the viewport.
  """

  @enforce_keys [:first_visible_row, :last_visible_row, :scroll_x, :scroll_y, :line_height]
  defstruct [:first_visible_row, :last_visible_row, :scroll_x, :scroll_y, :line_height]

  @type t :: %__MODULE__{
          first_visible_row: non_neg_integer(),
          last_visible_row: non_neg_integer(),
          scroll_x: float(),
          scroll_y: float(),
          line_height: float()
        }

  @doc "Decodes a protocol text-viewport map into a typed viewport value."
  @spec from_event(map()) :: t()
  def from_event(value) when is_map(value) do
    struct!(__MODULE__, value)
  end
end
