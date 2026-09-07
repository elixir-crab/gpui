# `GPUI.Text.StyleRun`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/style_run.ex#L1)

A neutral shaping style applied to a logical text range.

Style runs carry presentation facts only. They do not identify syntax,
diagnostics, languages, or semantic-token kinds. Positions remain zero-based
UTF-16 document coordinates and the native text surface converts them to
shaping ranges without changing buffer contents or history.

# `font_style`

```elixir
@type font_style() :: :normal | :italic | :oblique
```

# `font_weight`

```elixir
@type font_weight() ::
  :thin
  | :extra_light
  | :light
  | :normal
  | :medium
  | :semibold
  | :bold
  | :extra_bold
  | :black
```

# `rgb`

```elixir
@type rgb() :: 0..16_777_215
```

# `t`

```elixir
@type t() :: %GPUI.Text.StyleRun{
  color: rgb() | nil,
  font_style: font_style() | nil,
  font_weight: font_weight() | nil,
  range: GPUI.Text.Range.t()
}
```

# `new`

```elixir
@spec new(
  GPUI.Text.Range.t(),
  keyword()
) :: t()
```

# `validate!`

```elixir
@spec validate!(t()) :: t()
```

Validates a style run's color, font values, and non-empty presentation.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
