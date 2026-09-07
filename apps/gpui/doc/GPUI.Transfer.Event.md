# `GPUI.Transfer.Event`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/transfer/event.ex#L1)

A bounded renderer-independent drag/drop event fact.

`position` is expressed in the closed `:window_native_pixels` coordinate
space. External paths in `payload` always name resources on the machine
running the display; this value does not read or interpret them.

# `coordinate_space`

```elixir
@type coordinate_space() :: :window_native_pixels
```

# `position`

```elixir
@type position() :: {number(), number()}
```

# `t`

```elixir
@type t() :: %GPUI.Transfer.Event{
  coordinate_space: coordinate_space(),
  payload: GPUI.Transfer.Payload.t() | nil,
  position: position(),
  session_id: pos_integer(),
  target_id: String.t()
}
```

# `type`

```elixir
@type type() :: :drag_enter | :drag_move | :drag_leave | :drop
```

# `normalize`

```elixir
@spec normalize(type(), t() | map()) :: {:ok, t()} | {:error, term()}
```

Normalizes a native wire map or validates an existing transfer event value.

# `normalize!`

```elixir
@spec normalize!(type(), t() | map()) :: t()
```

Normalizes a transfer event value or raises `ArgumentError`.

# `to_payload`

```elixir
@spec to_payload(t()) :: map()
```

Converts a canonical transfer event into its serializable native/remote wire map.

# `type?`

```elixir
@spec type?(term()) :: boolean()
```

Returns whether a term is a supported drag/drop event type.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
