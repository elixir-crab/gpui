# `GPUI.Application.Identity`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/application/identity.ex#L1)

Stable process-wide identity for a GPUI application.

The identifier should use reverse-DNS form. `icon` names an application-owned
source asset or asset set; platform release tooling remains responsible for
producing macOS bundles, Windows resources, and Linux desktop entries.

# `t`

```elixir
@type t() :: %GPUI.Application.Identity{
  icon: GPUI.Application.Icon.t() | nil,
  id: String.t(),
  name: String.t()
}
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
