# `GPUI.Text.CaretGeometry`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/caret_geometry.ex#L1)

Window-relative native pixel bounds for a text surface's primary caret.

The logical position uses zero-based UTF-16 line coordinates. Bounds are
reported only while the caret is part of the currently laid-out viewport.

# `t`

```elixir
@type t() :: %GPUI.Text.CaretGeometry{
  height: float(),
  line: non_neg_integer(),
  utf16_offset: non_neg_integer(),
  width: float(),
  x: float(),
  y: float()
}
```

# `from_event`

```elixir
@spec from_event(map()) :: t()
```

Decodes a protocol caret-geometry map into a typed value.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
