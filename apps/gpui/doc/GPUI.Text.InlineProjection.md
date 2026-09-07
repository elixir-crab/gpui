# `GPUI.Text.InlineProjection`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/inline_projection.ex#L1)

Non-editable text rendered at an explicit logical text position.

Inline projections are visual only. They do not enter the Rope, affect
selection coordinates, participate in history, or imply completion policy.

# `rgb`

```elixir
@type rgb() :: 0..16_777_215
```

# `t`

```elixir
@type t() :: %GPUI.Text.InlineProjection{
  color: rgb(),
  position: GPUI.Text.Position.t(),
  text: String.t()
}
```

# `new`

```elixir
@spec new(GPUI.Text.Position.t(), String.t(), keyword()) :: t()
```

Creates a bounded inline projection at a logical position.

# `validate!`

```elixir
@spec validate!(t()) :: t()
```

Validates an inline projection's bounded text and color.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
