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

  @doc "Creates a directed selection from anchor to head."
  @spec new(String.t(), Position.t(), Position.t(), keyword()) :: t()
  def new(id, %Position{} = anchor, %Position{} = head, opts \\ [])
      when is_binary(id) and id != "" do
    primary = Keyword.get(opts, :primary, false)

    unless is_boolean(primary) do
      raise ArgumentError, "text selection primary must be a boolean"
    end

    %__MODULE__{id: id, anchor: anchor, head: head, primary: primary}
  end

  @doc "Creates a collapsed selection at a logical position."
  @spec caret(String.t(), Position.t(), keyword()) :: t()
  def caret(id, %Position{} = position, opts \\ []) when is_binary(id) and id != "" do
    new(id, position, position, opts)
  end
end
