defmodule GPUI.Text.Decoration do
  @moduledoc """
  A neutral visual annotation attached to a logical text range.

  Decorations carry rendering facts only. `background` and `underline` are
  six-digit RGB integers; consumers retain diagnostic, language, severity, and
  command policy outside the renderer primitive.
  """

  alias GPUI.Text.Range

  @enforce_keys [:range]
  defstruct [:range, :background, :underline]

  @type rgb :: 0x000000..0xFFFFFF
  @type t :: %__MODULE__{
          range: Range.t(),
          background: rgb() | nil,
          underline: rgb() | nil
        }

  @spec new(Range.t(), keyword()) :: t()
  def new(%Range{} = range, opts \\ []) do
    %__MODULE__{
      range: range,
      background: Keyword.get(opts, :background),
      underline: Keyword.get(opts, :underline)
    }
  end
end
