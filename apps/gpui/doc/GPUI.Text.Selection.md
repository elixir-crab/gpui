# `GPUI.Text.Selection`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/selection.ex#L1)

A directed selection represented by anchor and head positions.

# `t`

```elixir
@type t() :: %GPUI.Text.Selection{
  anchor: GPUI.Text.Position.t(),
  head: GPUI.Text.Position.t(),
  id: String.t(),
  primary: boolean()
}
```

# `caret`

```elixir
@spec caret(String.t(), GPUI.Text.Position.t(), keyword()) :: t()
```

Creates a collapsed selection at a logical position.

# `new`

```elixir
@spec new(String.t(), GPUI.Text.Position.t(), GPUI.Text.Position.t(), keyword()) ::
  t()
```

Creates a directed selection from anchor to head.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
