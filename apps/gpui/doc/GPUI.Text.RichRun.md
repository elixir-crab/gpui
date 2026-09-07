# `GPUI.Text.RichRun`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/rich_run.ex#L1)

A neutral shaping run for immutable rich text.

The half-open `range` uses zero-based `{line, utf16_offset}` positions. Runs
carry renderer facts only; Markdown, syntax, diagnostics, and product policy
remain consumer-owned. `link` is an opaque bounded application value emitted
through the rich text component's ordinary link event.

# `rgb`

```elixir
@type rgb() :: 0..16_777_215
```

# `t`

```elixir
@type t() :: %GPUI.Text.RichRun{
  background: rgb() | nil,
  color: rgb() | nil,
  font_style: atom() | nil,
  font_weight: atom() | nil,
  link: String.t() | nil,
  range: GPUI.Text.Range.t(),
  strikethrough: rgb() | nil,
  underline: rgb() | nil,
  underline_style: underline_style() | nil
}
```

# `underline_style`

```elixir
@type underline_style() :: :solid | :wavy
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
@spec validate!(t()) :: :ok
```

Validates the bounded styles, colors, range, and optional link of a rich run.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
