# `GPUI.Text.Edit`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/edit.ex#L1)

An atomic replacement of one half-open text range.

# `t`

```elixir
@type t() :: %GPUI.Text.Edit{range: GPUI.Text.Range.t(), text: String.t()}
```

# `insert`

```elixir
@spec insert(GPUI.Text.Position.t(), String.t()) :: t()
```

Creates an insertion edit at a logical position.

# `new`

```elixir
@spec new(GPUI.Text.Range.t(), String.t()) :: t()
```

Creates an atomic replacement for a half-open range.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
