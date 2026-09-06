defmodule GPUI.Text.Transaction do
  @moduledoc """
  A revisioned atomic set of text edits and resulting selections.

  Use `new/2` with a `GPUI.Text.Snapshot` when preparing an external edit. The
  constructor copies the snapshot revision and current selections, so callers
  specify only what changes. Pass `:selections` when the transaction should
  produce a different complete selection set.
  """

  alias GPUI.Text.{Edit, Selection, Snapshot}

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

  @doc "Builds a validated transaction against the supplied text snapshot."
  @spec new(Snapshot.t(), keyword()) :: t()
  def new(%Snapshot{} = snapshot, opts) when is_list(opts) do
    transaction = %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      base_revision: snapshot.revision,
      origin: Keyword.get(opts, :origin, :external),
      edits: Keyword.get(opts, :edits, []),
      selections: Keyword.get(opts, :selections, snapshot.selections)
    }

    validate!(transaction)
  end

  @doc "Validates a transaction's public shape and returns it."
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = transaction) do
    unless is_binary(transaction.id) and transaction.id != "" do
      raise ArgumentError, "text transaction id must be a non-empty string"
    end

    unless is_integer(transaction.base_revision) and transaction.base_revision >= 0 do
      raise ArgumentError, "text transaction base_revision must be a non-negative integer"
    end

    unless is_atom(transaction.origin) or is_binary(transaction.origin) do
      raise ArgumentError, "text transaction origin must be an atom or string"
    end

    unless is_list(transaction.edits) and Enum.all?(transaction.edits, &match?(%Edit{}, &1)) do
      raise ArgumentError, "text transaction edits must be GPUI.Text.Edit values"
    end

    unless is_list(transaction.selections) and
             Enum.all?(transaction.selections, &match?(%Selection{}, &1)) do
      raise ArgumentError, "text transaction selections must be GPUI.Text.Selection values"
    end

    transaction
  end
end
