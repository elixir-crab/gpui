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

  @spec new(non_neg_integer(), String.t(), keyword()) :: t()
  def new(line, text, opts \\ []) when is_integer(line) and line >= 0 and is_binary(text) do
    %__MODULE__{
      line: line,
      text: text,
      placement: Keyword.get(opts, :placement, :after),
      height: Keyword.get(opts, :height, 24),
      color: Keyword.get(opts, :color, 0xCBD5E1),
      background: Keyword.get(opts, :background)
    }
  end
end
