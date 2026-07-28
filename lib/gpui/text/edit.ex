defmodule GPUI.Text.Edit do
  @moduledoc "An atomic replacement of one half-open text range."

  alias GPUI.Text.Range

  @enforce_keys [:range, :text]
  defstruct [:range, :text]

  @type t :: %__MODULE__{range: Range.t(), text: String.t()}

  @spec new(Range.t(), String.t()) :: t()
  def new(%Range{} = range, text) when is_binary(text), do: %__MODULE__{range: range, text: text}
end
