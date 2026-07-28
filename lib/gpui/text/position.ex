defmodule GPUI.Text.Position do
  @moduledoc """
  A zero-based logical text position.

  `utf16_offset` counts UTF-16 code units from the beginning of `line`. It is
  deliberately explicit so positions can be exchanged with language servers
  without treating byte, code-point, and UTF-16 offsets as interchangeable.
  """

  @enforce_keys [:line, :utf16_offset]
  defstruct [:line, :utf16_offset]

  @type t :: %__MODULE__{line: non_neg_integer(), utf16_offset: non_neg_integer()}

  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(line, utf16_offset)
      when is_integer(line) and line >= 0 and is_integer(utf16_offset) and utf16_offset >= 0,
      do: %__MODULE__{line: line, utf16_offset: utf16_offset}
end
