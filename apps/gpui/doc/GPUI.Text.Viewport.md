# `GPUI.Text.Viewport`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/viewport.ex#L1)

A revision-tagged snapshot of one text surface's visible visual rows.

Scroll coordinates are native GPUI pixels relative to the surface's laid-out
text viewport. Offsets are typically zero or negative as content moves above
or to the left of the viewport.

# `t`

```elixir
@type t() :: %GPUI.Text.Viewport{
  first_visible_row: non_neg_integer(),
  last_visible_row: non_neg_integer(),
  line_height: float(),
  scroll_x: float(),
  scroll_y: float()
}
```

# `from_event`

```elixir
@spec from_event(map()) :: t()
```

Decodes a protocol text-viewport map into a typed viewport value.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
