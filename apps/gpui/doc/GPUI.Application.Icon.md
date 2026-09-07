# `GPUI.Application.Icon`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/application/icon.ex#L1)

Application-owned icon source metadata.

`source` is a relative path to an icon asset or asset directory. Platform
packaging remains responsible for producing bundle, executable, and desktop
integration resources.

# `t`

```elixir
@type t() :: %GPUI.Application.Icon{description: String.t() | nil, source: String.t()}
```

# `new!`

```elixir
@spec new!(keyword() | map()) :: t()
```

# `validate!`

```elixir
@spec validate!(t()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
