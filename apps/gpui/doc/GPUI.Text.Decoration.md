# `GPUI.Text.Decoration`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/decoration.ex#L1)

A neutral visual annotation attached to a logical text range.

Decorations carry rendering facts only. `background` and `underline` are
six-digit RGB integers; consumers retain diagnostic, language, severity, and
command policy outside the renderer primitive.

# `rgb`

```elixir
@type rgb() :: 0..16_777_215
```

# `t`

```elixir
@type t() :: %GPUI.Text.Decoration{
  background: rgb() | nil,
  range: GPUI.Text.Range.t(),
  underline: rgb() | nil,
  underline_style: underline_style()
}
```

# `underline_style`

```elixir
@type underline_style() :: :solid | :dashed | :wavy
```

# `new`

```elixir
@spec new(
  GPUI.Text.Range.t(),
  keyword()
) :: t()
```

Creates a validated visual decoration for a logical text range.

# `validate!`

```elixir
@spec validate!(t()) :: t()
```

Validates a decoration's colors and underline style.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
