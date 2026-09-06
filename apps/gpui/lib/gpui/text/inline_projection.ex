defmodule GPUI.Text.InlineProjection do
  @moduledoc """
  Non-editable text rendered at an explicit logical text position.

  Inline projections are visual only. They do not enter the Rope, affect
  selection coordinates, participate in history, or imply completion policy.
  """

  alias GPUI.Text.Position

  @enforce_keys [:position, :text]
  defstruct [:position, :text, color: 0x94A3B8]

  @type rgb :: 0x000000..0xFFFFFF
  @type t :: %__MODULE__{position: Position.t(), text: String.t(), color: rgb()}

  @doc "Creates a bounded inline projection at a logical position."
  @spec new(Position.t(), String.t(), keyword()) :: t()
  def new(%Position{} = position, text, opts \\ []) when is_binary(text) do
    color = Keyword.get(opts, :color, 0x94A3B8)

    projection = %__MODULE__{position: position, text: text, color: color}
    validate!(projection)
  end

  @doc "Validates an inline projection's bounded text and color."
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = projection) do
    unless is_binary(projection.text) and byte_size(projection.text) <= 4_096 and
             String.valid?(projection.text) do
      raise ArgumentError, "inline projection text must be valid UTF-8 no larger than 4096 bytes"
    end

    unless is_integer(projection.color) and projection.color in 0..0xFFFFFF do
      raise ArgumentError, "inline projection color must be a six-digit RGB integer"
    end

    projection
  end
end
