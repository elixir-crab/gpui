# `GPUI.Text.Range`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/range.ex#L1)

A half-open range between two `GPUI.Text.Position` values.

# `t`

```elixir
@type t() :: %GPUI.Text.Range{
  end: GPUI.Text.Position.t(),
  start: GPUI.Text.Position.t()
}
```

# `caret`

```elixir
@spec caret(GPUI.Text.Position.t()) :: t()
```

Creates a collapsed range at a logical position.

# `new`

```elixir
@spec new(GPUI.Text.Position.t(), GPUI.Text.Position.t()) :: t()
```

Creates a half-open range between two logical positions.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
