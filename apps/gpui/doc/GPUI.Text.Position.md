# `GPUI.Text.Position`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/text/position.ex#L1)

A zero-based logical text position.

`utf16_offset` counts UTF-16 code units from the beginning of `line`. It is
deliberately explicit so positions can be exchanged with language servers
without treating byte, code-point, and UTF-16 offsets as interchangeable.

# `t`

```elixir
@type t() :: %GPUI.Text.Position{
  line: non_neg_integer(),
  utf16_offset: non_neg_integer()
}
```

# `new`

```elixir
@spec new(non_neg_integer(), non_neg_integer()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
