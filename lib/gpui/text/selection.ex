defmodule GPUI.Text.Selection do
  @moduledoc "A directed selection represented by anchor and head positions."

  alias GPUI.Text.Position

  @enforce_keys [:id, :anchor, :head]
  defstruct [:id, :anchor, :head, primary: false]

  @type t :: %__MODULE__{
          id: String.t(),
          anchor: Position.t(),
          head: Position.t(),
          primary: boolean()
        }

  @spec caret(String.t(), Position.t(), keyword()) :: t()
  def caret(id, %Position{} = position, opts \\ []) when is_binary(id) and id != "" do
    %__MODULE__{
      id: id,
      anchor: position,
      head: position,
      primary: Keyword.get(opts, :primary, false)
    }
  end
end
