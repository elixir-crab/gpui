# `GPUI.Transfer.Payload`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/transfer/payload.ex#L1)

Bounded renderer-independent clipboard or drag/drop facts.

External paths always refer to the machine running the display. A payload
does not read files, infer MIME types, upload content, or assign product
meaning to paths.

# `t`

```elixir
@type t() :: %GPUI.Transfer.Payload{
  external_paths: [String.t()],
  text: String.t() | nil
}
```

# `new`

```elixir
@spec new(keyword() | map()) :: t()
```

# `to_payload`

```elixir
@spec to_payload(t()) :: map()
```

Converts a canonical transfer payload into a serializable map.

# `validate!`

```elixir
@spec validate!(t()) :: :ok
```

Validates that a transfer payload is already canonical and bounded.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
