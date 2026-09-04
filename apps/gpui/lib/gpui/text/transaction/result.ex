defmodule GPUI.Text.Transaction.Result do
  @moduledoc """
  Result of applying a `GPUI.Text.Transaction` to a persistent text buffer.

  `duplicate` is true when an identical transaction ID and payload was already
  applied. The resulting selections are decoded public `GPUI.Text.Selection`
  values.
  """

  @enforce_keys [:revision, :duplicate, :selections]
  defstruct [:revision, :duplicate, :selections]

  @type t :: %__MODULE__{
          revision: non_neg_integer(),
          duplicate: boolean(),
          selections: [GPUI.Text.Selection.t()]
        }
end
