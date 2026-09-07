# `GPUI.Text.Rectangle`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/rectangle.ex#L1)

Window-relative native pixel rectangle for laid-out text.

# `t`

```elixir
@type t() :: %GPUI.Text.Rectangle{
  height: float(),
  width: float(),
  x: float(),
  y: float()
}
```

# `from_event`

```elixir
@spec from_event(map()) :: t()
```

Decodes a protocol rectangle map into a typed rectangle value.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
