defmodule GPUI.Text.Transaction do
  @moduledoc "A revisioned atomic set of text edits and resulting selections."

  alias GPUI.Text.{Edit, Selection}

  @enforce_keys [:id, :base_revision, :edits, :selections]
  defstruct [:id, :base_revision, :edits, :selections, origin: :external]

  @type origin :: atom() | String.t()
  @type t :: %__MODULE__{
          id: String.t(),
          base_revision: non_neg_integer(),
          origin: origin(),
          edits: [Edit.t()],
          selections: [Selection.t()]
        }
end
