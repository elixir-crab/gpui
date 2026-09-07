# `GPUI.Raster`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/raster.ex#L1)

Generic packed 32-bit CPU raster image payload for GPUI image elements.

This is renderer-independent: image decoders, screenshots, video frames, or
tensors can produce `%GPUI.Raster{}` values. Rows may be tightly packed or
use an explicit byte stride.

# `format`

```elixir
@type format() :: :rgba8 | :bgra8
```

# `t`

```elixir
@type t() :: %GPUI.Raster{
  data: binary(),
  format: format(),
  height: pos_integer(),
  stride: pos_integer() | nil,
  width: pos_integer()
}
```

# `new`

```elixir
@spec new(pos_integer(), pos_integer(), binary(), keyword()) :: t()
```

# `to_payload`

```elixir
@spec to_payload(t()) :: map()
```

Converts a validated raster into its renderer-independent payload.

# `validate!`

```elixir
@spec validate!(t()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
