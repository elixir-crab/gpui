# `GPUI.Text.Snapshot`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/snapshot.ex#L1)

An immutable snapshot of a persistent native text buffer.

# `t`

```elixir
@type t() :: %GPUI.Text.Snapshot{
  can_redo: boolean(),
  can_undo: boolean(),
  revision: non_neg_integer(),
  selections: [GPUI.Text.Selection.t()],
  text: String.t()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
