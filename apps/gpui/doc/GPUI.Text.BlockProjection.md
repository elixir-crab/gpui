# `GPUI.Text.BlockProjection`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/block_projection.ex#L1)

A non-editable block rendered adjacent to an explicit logical text line.

Blocks are visual annotations only. They do not enter the Rope, create visual
rows inside text layout, affect selections, or participate in history.

# `placement`

```elixir
@type placement() :: :before | :after
```

# `rgb`

```elixir
@type rgb() :: 0..16_777_215
```

# `t`

```elixir
@type t() :: %GPUI.Text.BlockProjection{
  background: rgb() | nil,
  color: rgb(),
  height: pos_integer(),
  line: non_neg_integer(),
  placement: placement(),
  text: String.t()
}
```

# `new`

```elixir
@spec new(non_neg_integer(), String.t(), keyword()) :: t()
```

Creates a bounded non-editable block adjacent to a logical text line.

# `validate!`

```elixir
@spec validate!(t()) :: t()
```

Validates a block projection's bounded text and presentation values.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
