defmodule GPUI.Text.StyleRun do
  @moduledoc """
  A neutral shaping style applied to a logical text range.

  Style runs carry presentation facts only. They do not identify syntax,
  diagnostics, languages, or semantic-token kinds. Positions remain zero-based
  UTF-16 document coordinates and the native text surface converts them to
  shaping ranges without changing buffer contents or history.
  """

  alias GPUI.Text.Range

  @weights [:thin, :extra_light, :light, :normal, :medium, :semibold, :bold, :extra_bold, :black]
  @styles [:normal, :italic, :oblique]

  @enforce_keys [:range]
  defstruct [:range, :color, :font_weight, :font_style]

  @type rgb :: 0x000000..0xFFFFFF
  @type font_weight ::
          :thin
          | :extra_light
          | :light
          | :normal
          | :medium
          | :semibold
          | :bold
          | :extra_bold
          | :black
  @type font_style :: :normal | :italic | :oblique
  @type t :: %__MODULE__{
          range: Range.t(),
          color: rgb() | nil,
          font_weight: font_weight() | nil,
          font_style: font_style() | nil
        }

  @spec new(Range.t(), keyword()) :: t()
  def new(%Range{} = range, opts \\ []) do
    color = Keyword.get(opts, :color)
    weight = Keyword.get(opts, :font_weight)
    style = Keyword.get(opts, :font_style)

    run = %__MODULE__{range: range, color: color, font_weight: weight, font_style: style}
    validate!(run)
  end

  @doc "Validates a style run's color, font values, and non-empty presentation."
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = run) do
    validate_color!(run.color)
    validate_weight!(run.font_weight)
    validate_style!(run.font_style)
    validate_present!(run.color, run.font_weight, run.font_style)
    run
  end

  defp validate_color!(nil), do: :ok
  defp validate_color!(color) when is_integer(color) and color in 0..0xFFFFFF, do: :ok

  defp validate_color!(_color),
    do: raise(ArgumentError, "style run color must be a six-digit RGB integer")

  defp validate_weight!(nil), do: :ok
  defp validate_weight!(weight) when weight in @weights, do: :ok

  defp validate_weight!(_weight),
    do: raise(ArgumentError, "style run font_weight must be one of #{inspect(@weights)}")

  defp validate_style!(nil), do: :ok
  defp validate_style!(style) when style in @styles, do: :ok

  defp validate_style!(_style),
    do: raise(ArgumentError, "style run font_style must be one of #{inspect(@styles)}")

  defp validate_present!(nil, nil, nil),
    do: raise(ArgumentError, "style run must set color, font_weight, or font_style")

  defp validate_present!(_color, _weight, _style), do: :ok
end
