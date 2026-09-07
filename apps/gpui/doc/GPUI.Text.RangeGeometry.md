# `GPUI.Text.RangeGeometry`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/range_geometry.ex#L1)

Window-relative native pixel bounds for one requested logical text range.

Range geometry is bounded to at most 64 requests per surface and includes
only ranges present in the current native layout. Each result contains a
bounded rectangle for every visual row crossed by wrapped text.

# `t`

```elixir
@type t() :: %GPUI.Text.RangeGeometry{
  range: GPUI.Text.Range.t(),
  rectangles: [GPUI.Text.Rectangle.t()]
}
```

# `from_event`

```elixir
@spec from_event(map()) :: t()
```

Decodes a protocol range-geometry map into a typed value.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
