defmodule GPUI.Text.Range do
  @moduledoc "A half-open range between two `GPUI.Text.Position` values."

  alias GPUI.Text.Position

  @enforce_keys [:start, :end]
  defstruct [:start, :end]

  @type t :: %__MODULE__{start: Position.t(), end: Position.t()}

  @doc "Creates a collapsed range at a logical position."
  @spec caret(Position.t()) :: t()
  def caret(%Position{} = position), do: new(position, position)

  @doc "Creates a half-open range between two logical positions."
  @spec new(Position.t(), Position.t()) :: t()
  def new(%Position{} = start_position, %Position{} = end_position),
    do: %__MODULE__{start: start_position, end: end_position}
end
