defmodule GPUI.Text.RichRun do
  @moduledoc """
  A neutral shaping run for immutable rich text.

  The half-open `range` uses zero-based `{line, utf16_offset}` positions. Runs
  carry renderer facts only; Markdown, syntax, diagnostics, and product policy
  remain consumer-owned. `link` is an opaque bounded application value emitted
  through the rich text component's ordinary link event.
  """

  alias GPUI.Text.Range

  @weights [:thin, :extra_light, :light, :normal, :medium, :semibold, :bold, :extra_bold, :black]
  @styles [:normal, :italic, :oblique]
  @underline_styles [:solid, :wavy]

  @enforce_keys [:range]
  defstruct [
    :range,
    :color,
    :background,
    :font_weight,
    :font_style,
    :underline,
    :underline_style,
    :strikethrough,
    :link
  ]

  @type rgb :: 0x000000..0xFFFFFF
  @type underline_style :: :solid | :wavy
  @type t :: %__MODULE__{
          range: Range.t(),
          color: rgb() | nil,
          background: rgb() | nil,
          font_weight: atom() | nil,
          font_style: atom() | nil,
          underline: rgb() | nil,
          underline_style: underline_style() | nil,
          strikethrough: rgb() | nil,
          link: String.t() | nil
        }

  @spec new(Range.t(), keyword()) :: t()
  def new(%Range{} = range, opts \\ []) do
    run = struct!(__MODULE__, Keyword.put(opts, :range, range))
    validate!(run)
    run
  end

  @doc "Validates the bounded styles, colors, range, and optional link of a rich run."
  @spec validate!(t()) :: :ok
  def validate!(%__MODULE__{} = run) do
    validate_colors!(run)
    validate_font!(run)
    validate_underline!(run)
    validate_link!(run.link)
    validate_present!(run)
    :ok
  end

  defp validate_colors!(run),
    do:
      Enum.each(
        [run.color, run.background, run.underline, run.strikethrough],
        &validate_color!/1
      )

  defp validate_font!(run) do
    unless is_nil(run.font_weight) or run.font_weight in @weights do
      raise ArgumentError, "rich run font_weight must be one of #{inspect(@weights)}"
    end

    unless is_nil(run.font_style) or run.font_style in @styles do
      raise ArgumentError, "rich run font_style must be one of #{inspect(@styles)}"
    end
  end

  defp validate_underline!(run) do
    unless is_nil(run.underline_style) or run.underline_style in @underline_styles do
      raise ArgumentError, "rich run underline_style must be solid or wavy"
    end

    if run.underline_style && is_nil(run.underline) do
      raise ArgumentError, "rich run underline_style requires underline"
    end
  end

  defp validate_link!(nil), do: :ok

  defp validate_link!(link)
       when is_binary(link) and link != "" and byte_size(link) <= 2_048,
       do: :ok

  defp validate_link!(_link),
    do: raise(ArgumentError, "rich run link must be a non-empty string no larger than 2048 bytes")

  defp validate_present!(run) do
    if Enum.all?(
         [
           run.color,
           run.background,
           run.font_weight,
           run.font_style,
           run.underline,
           run.strikethrough,
           run.link
         ],
         &is_nil/1
       ) do
      raise ArgumentError, "rich run must set a shaping, decoration, or link fact"
    end
  end

  defp validate_color!(nil), do: :ok
  defp validate_color!(color) when is_integer(color) and color in 0..0xFFFFFF, do: :ok

  defp validate_color!(_color),
    do: raise(ArgumentError, "rich run colors must be six-digit RGB integers")
end
