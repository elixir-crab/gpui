# `GPUI.Schema.Extension`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/schema/extension.ex#L1)

Compile-time metadata for one versioned renderer presentation contract.

# `t`

```elixir
@type t() :: %GPUI.Schema.Extension{
  capabilities: [atom()],
  id: atom(),
  version: pos_integer()
}
```

# `max_capabilities`

```elixir
@spec max_capabilities() :: pos_integer()
```

Maximum capabilities declared or advertised for one extension version.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
