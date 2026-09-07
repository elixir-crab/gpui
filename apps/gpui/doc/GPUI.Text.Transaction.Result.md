# `GPUI.Text.Transaction.Result`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/transaction/result.ex#L1)

Result of applying a `GPUI.Text.Transaction` to a persistent text buffer.

`duplicate` is true when an identical transaction ID and payload was already
applied. The resulting selections are decoded public `GPUI.Text.Selection`
values.

# `t`

```elixir
@type t() :: %GPUI.Text.Transaction.Result{
  duplicate: boolean(),
  revision: non_neg_integer(),
  selections: [GPUI.Text.Selection.t()]
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
