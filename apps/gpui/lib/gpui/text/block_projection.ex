defmodule GPUI.Text.BlockProjection do
  @moduledoc """
  A non-editable block rendered adjacent to an explicit logical text line.

  Blocks are visual annotations only. They do not enter the Rope, create visual
  rows inside text layout, affect selections, or participate in history.
  """

  @enforce_keys [:line, :text]
  defstruct [:line, :text, :placement, :height, :color, :background]

  @type rgb :: 0x000000..0xFFFFFF
  @type placement :: :before | :after
  @type t :: %__MODULE__{
          line: non_neg_integer(),
          text: String.t(),
          placement: placement(),
          height: pos_integer(),
          color: rgb(),
          background: rgb() | nil
        }

  @doc "Creates a bounded non-editable block adjacent to a logical text line."
  @spec new(non_neg_integer(), String.t(), keyword()) :: t()
  def new(line, text, opts \\ []) when is_integer(line) and line >= 0 and is_binary(text) do
    block = %__MODULE__{
      line: line,
      text: text,
      placement: Keyword.get(opts, :placement, :after),
      height: Keyword.get(opts, :height, 24),
      color: Keyword.get(opts, :color, 0xCBD5E1),
      background: Keyword.get(opts, :background)
    }

    validate!(block)
  end

  @doc "Validates a block projection's bounded text and presentation values."
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = block) do
    unless String.valid?(block.text) and byte_size(block.text) <= 16_384 do
      raise ArgumentError, "block projection text must be valid UTF-8 no larger than 16384 bytes"
    end

    unless block.placement in [:before, :after] do
      raise ArgumentError, "block projection placement must be :before or :after"
    end

    unless is_integer(block.height) and block.height in 1..512 do
      raise ArgumentError, "block projection height must be an integer from 1 through 512"
    end

    Enum.each([block.color, block.background], fn color ->
      unless is_nil(color) or (is_integer(color) and color in 0..0xFFFFFF) do
        raise ArgumentError, "block projection colors must be six-digit RGB integers or nil"
      end
    end)

    block
  end
end
