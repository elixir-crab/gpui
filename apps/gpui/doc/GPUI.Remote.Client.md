# `GPUI.Remote.Client`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/remote/client.ex#L1)

Display-side client for a remote GPUI application session.

The client owns a local display, synchronizes remote snapshots into it, and
forwards local display events to `GPUI.Remote.Server`.

## Options

  * `:host` and `:port` - required remote endpoint;
  * `:ssl` - `false` or SafeRPC TLS options;
  * `:display` - local display module, defaulting to `GPUI.Display.Native`;
  * `:display_opts` - options passed to the display;
  * `:session_id` - stable session identity, generated when omitted;
  * `:poll_interval` - positive milliseconds or `nil` to disable display
    polling, defaulting to `16`;
  * `:name` - optional client process name.

# `await_frame`

```elixir
@spec await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
  :ok | {:error, term()}
```

Waits until a complete display frame follows the current window state.

# `await_frame_after`

```elixir
@spec await_frame_after(
  GenServer.server(),
  pos_integer(),
  non_neg_integer(),
  pos_integer()
) ::
  :ok | {:error, term()}
```

Waits for a display frame completed after the supplied generation.

# `child_spec`

```elixir
@spec child_spec(keyword()) :: Supervisor.child_spec()
```

Builds the remote client's OTP child specification.

# `event`

```elixir
@spec event(GenServer.server(), map()) :: {:ok, GPUI.Snapshot.t()} | {:error, term()}
```

Dispatches one normalized event remotely and synchronizes its snapshot.

# `frame_token`

```elixir
@spec frame_token(GenServer.server(), pos_integer()) ::
  {:ok, non_neg_integer()} | {:error, term()}
```

Returns the latest completed display frame generation for a window.

# `mount`

```elixir
@spec mount(GenServer.server(), map() | keyword()) ::
  {:ok, GPUI.Snapshot.t()} | {:error, term()}
```

Mounts or remounts the configured application session and synchronizes its snapshot.

# `snapshot`

```elixir
@spec snapshot(GenServer.server()) :: {:ok, GPUI.Snapshot.t()} | {:error, term()}
```

Fetches and synchronizes the current remote session snapshot.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

Starts a remote display client linked to the caller.

# `subscribe`

```elixir
@spec subscribe(GenServer.server()) :: :ok
```

Subscribes the calling process to synchronized remote display updates.

# `unsubscribe`

```elixir
@spec unsubscribe(GenServer.server()) :: :ok
```

Unsubscribes the calling process from remote display updates.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
