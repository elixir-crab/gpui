defmodule GPUI.Text.Decoration do
  @moduledoc """
  A neutral visual annotation attached to a logical text range.

  Decorations carry rendering facts only. `background` and `underline` are
  six-digit RGB integers; consumers retain diagnostic, language, severity, and
  command policy outside the renderer primitive.
  """

  alias GPUI.Text.Range

  @enforce_keys [:range]
  defstruct [:range, :background, :underline, underline_style: :solid]

  @type underline_style :: :solid | :dashed | :wavy

  @type rgb :: 0x000000..0xFFFFFF
  @type t :: %__MODULE__{
          range: Range.t(),
          background: rgb() | nil,
          underline: rgb() | nil,
          underline_style: underline_style()
        }

  @doc "Creates a validated visual decoration for a logical text range."
  @spec new(Range.t(), keyword()) :: t()
  def new(%Range{} = range, opts \\ []) do
    decoration = %__MODULE__{
      range: range,
      background: Keyword.get(opts, :background),
      underline: Keyword.get(opts, :underline),
      underline_style: Keyword.get(opts, :underline_style, :solid)
    }

    validate!(decoration)
  end

  @doc "Validates a decoration's colors and underline style."
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = decoration) do
    Enum.each([decoration.background, decoration.underline], fn color ->
      unless is_nil(color) or (is_integer(color) and color in 0..0xFFFFFF) do
        raise ArgumentError, "decoration colors must be six-digit RGB integers or nil"
      end
    end)

    unless decoration.underline_style in [:solid, :dashed, :wavy] do
      raise ArgumentError, "decoration underline_style must be :solid, :dashed, or :wavy"
    end

    decoration
  end
end
