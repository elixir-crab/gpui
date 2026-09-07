# `GPUI.Text.Buffer`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/buffer.ex#L1)

Persistent native Rope text storage with revisioned atomic edits.

`GPUI.Text.Buffer` requires the `gpui_native` package because its Rope storage
is a native resource. If that package is absent or disabled, operations return
`{:error, :native_backend_unavailable}` rather than calling an unavailable
module.

This is a model primitive. It does not represent a file, editor, language,
gutter, or workspace. Consumers own those policies and may later attach one
or more renderer primitives to the same buffer.

# `result`

```elixir
@type result(value) :: {:ok, value} | {:error, term()}
```

# `t`

```elixir
@opaque t()
```

# `new`

```elixir
@spec new(
  String.t(),
  keyword()
) :: result(t())
```

Creates a native text buffer with one primary selection.

# `redo`

```elixir
@spec redo(t(), non_neg_integer()) :: result(GPUI.Text.Snapshot.t())
```

Redoes one native transaction and creates a new monotonic revision.

# `snapshot`

```elixir
@spec snapshot(t()) :: result(GPUI.Text.Snapshot.t())
```

Returns the current text, revision, selections, and history availability.

# `transact`

```elixir
@spec transact(t(), GPUI.Text.Transaction.t()) ::
  result(GPUI.Text.Transaction.Result.t())
```

Atomically applies a transaction based on the current revision.

# `undo`

```elixir
@spec undo(t(), non_neg_integer()) :: result(GPUI.Text.Snapshot.t())
```

Undoes one native transaction and creates a new monotonic revision.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
