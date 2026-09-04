defmodule GPUI.Text.Edit do
  @moduledoc "An atomic replacement of one half-open text range."

  alias GPUI.Text.{Position, Range}

  @enforce_keys [:range, :text]
  defstruct [:range, :text]

  @type t :: %__MODULE__{range: Range.t(), text: String.t()}

  @doc "Creates an insertion edit at a logical position."
  @spec insert(Position.t(), String.t()) :: t()
  def insert(%Position{} = position, text) when is_binary(text),
    do: new(Range.caret(position), text)

  @doc "Creates an atomic replacement for a half-open range."
  @spec new(Range.t(), String.t()) :: t()
  def new(%Range{} = range, text) when is_binary(text), do: %__MODULE__{range: range, text: text}
end
