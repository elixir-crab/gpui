defmodule GPUI.Text.Snapshot do
  @moduledoc "An immutable snapshot of a persistent native text buffer."

  alias GPUI.Text.Selection

  @enforce_keys [:revision, :text, :selections, :can_undo, :can_redo]
  defstruct [:revision, :text, :selections, :can_undo, :can_redo]

  @type t :: %__MODULE__{
          revision: non_neg_integer(),
          text: String.t(),
          selections: [Selection.t()],
          can_undo: boolean(),
          can_redo: boolean()
        }
end
