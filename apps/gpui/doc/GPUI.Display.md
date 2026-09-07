# `GPUI.Display`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/display.ex#L1)

Behaviour for displays that present GPUI snapshots and return input events.

Displays own renderer-specific lifecycle and resources while application
sessions remain renderer-independent. Implementations provide process startup,
snapshot synchronization, event draining, and deterministic event injection.
Frame barriers and presentation capabilities are optional.

Framework runtimes invoke this contract through an internal support layer that
validates callback results and turns callback failures into structured errors.

# `event`

```elixir
@type event() :: GPUI.Event.payload()
```

# `snapshot`

```elixir
@type snapshot() :: GPUI.Snapshot.t()
```

# `await_frame`
*optional* 

```elixir
@callback await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
  :ok | {:error, term()}
```

# `await_frame_after`
*optional* 

```elixir
@callback await_frame_after(
  GenServer.server(),
  pos_integer(),
  non_neg_integer(),
  pos_integer()
) :: :ok | {:error, term()}
```

# `drain_events`

```elixir
@callback drain_events(GenServer.server()) :: {:ok, [event()]} | {:error, term()}
```

# `frame_token`
*optional* 

```elixir
@callback frame_token(GenServer.server(), pos_integer()) ::
  {:ok, non_neg_integer()} | {:error, term()}
```

# `inject_event`

```elixir
@callback inject_event(GenServer.server(), map()) :: {:ok, term()} | {:error, term()}
```

# `presentation_capabilities`
*optional* 

```elixir
@callback presentation_capabilities(GenServer.server()) ::
  {:ok, [GPUI.Schema.Extension.Support.t()]} | {:error, term()}
```

# `start_link`

```elixir
@callback start_link(keyword()) :: GenServer.on_start()
```

# `sync`

```elixir
@callback sync(GenServer.server(), snapshot()) :: :ok | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
