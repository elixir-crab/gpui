# `GPUI.Schema.Extension.Support`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/schema/extension/support.ex#L1)

Bounded display support for one exact presentation contract version.

# `t`

```elixir
@type t() :: %GPUI.Schema.Extension.Support{
  capabilities: [atom()],
  id: atom(),
  version: pos_integer()
}
```

# `max_contracts`

```elixir
@spec max_contracts() :: pos_integer()
```

Maximum extension contracts advertised by one display or remote peer.

# `new`

```elixir
@spec new(atom(), pos_integer(), [atom()]) :: {:ok, t()} | {:error, term()}
```

Builds and validates support against the canonical schema contract.

# `provides?`

```elixir
@spec provides?(t(), atom(), pos_integer(), atom() | nil) :: boolean()
```

Tests whether support provides one exact contract version and optional capability.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
