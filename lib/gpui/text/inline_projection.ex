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

  @spec new(Position.t(), String.t(), keyword()) :: t()
  def new(%Position{} = position, text, opts \\ []) when is_binary(text) do
    %__MODULE__{position: position, text: text, color: Keyword.get(opts, :color, 0x94A3B8)}
  end
end
