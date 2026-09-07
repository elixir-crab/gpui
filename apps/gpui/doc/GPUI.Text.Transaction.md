# `GPUI.Text.Transaction`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/transaction.ex#L1)

A revisioned atomic set of text edits and resulting selections.

Use `new/2` with a `GPUI.Text.Snapshot` when preparing an external edit. The
constructor copies the snapshot revision and current selections, so callers
specify only what changes. Pass `:selections` when the transaction should
produce a different complete selection set.

# `origin`

```elixir
@type origin() :: atom() | String.t()
```

# `t`

```elixir
@type t() :: %GPUI.Text.Transaction{
  base_revision: non_neg_integer(),
  edits: [GPUI.Text.Edit.t()],
  id: String.t(),
  origin: origin(),
  selections: [GPUI.Text.Selection.t()]
}
```

# `new`

```elixir
@spec new(
  GPUI.Text.Snapshot.t(),
  keyword()
) :: t()
```

Builds a validated transaction against the supplied text snapshot.

# `validate!`

```elixir
@spec validate!(t()) :: t()
```

Validates a transaction's public shape and returns it.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
