# `GPUI.Runtime`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/runtime.ex#L1)

Primary application-facing process API for one GPUI application and display.

A runtime starts the renderer-independent `GPUI.Session`, owns the configured
`GPUI.Display`, synchronizes authoritative snapshots, drains strict typed
display events, and publishes completed updates to subscribers. Applications
normally supervise their `GPUI.Application`, whose child specification starts
this process; direct `GPUI.Session` use is reserved for remote hosting and
custom display infrastructure.

Use this module for application operations such as snapshots, resources,
dynamic windows, view messages, subscriptions, and frame barriers.

## Options

  * `:app` - required `GPUI.Application` module;
  * `:args` - application mount argument, defaulting to `[]`;
  * `:display` - display module, defaulting to `GPUI.Display.Native`;
  * `:display_opts` - options passed to the display;
  * `:poll_interval` - positive milliseconds or `nil` to disable polling,
    defaulting to `16`;
  * `:name` - optional runtime process name.

# `display_error`

```elixir
@type display_error() ::
  {:display_start_failed, term()}
  | {:display_sync_failed, term()}
  | {:display_drain_failed, term()}
  | {:display_inject_failed, term()}
```

# `error`

```elixir
@type error() ::
  GPUI.Session.operation_error()
  | GPUI.Session.topology_error()
  | display_error()
```

# `state`

```elixir
@type state() :: %{
  application: module(),
  identity: GPUI.Application.Identity.t() | nil,
  session: pid(),
  display: pid(),
  display_module: module(),
  events: [map()],
  poll_interval: pos_integer() | nil,
  revision: non_neg_integer(),
  subscribers: %{required(pid()) =&gt; reference()},
  unsynchronized?: boolean()
}
```

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

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `close_window`

```elixir
@spec close_window(GenServer.server(), GPUI.WindowSpec.key() | pos_integer()) ::
  {:ok, GPUI.Snapshot.t()} | {:error, GPUI.Session.topology_error()}
```

Closes a declarative window by key or session ID and synchronizes the display.

# `dispatch_event`

```elixir
@spec dispatch_event(GenServer.server(), map()) ::
  {:ok, map(), GPUI.Snapshot.t()} | {:error, error()}
```

Validates and dispatches one explicit typed event and synchronizes the resulting snapshot.

# `drain_events`

```elixir
@spec drain_events(GenServer.server()) :: {:ok, [map()]} | {:error, error()}
```

Drains display events, applies them to the session, and synchronizes the result.

# `drop_resource`

```elixir
@spec drop_resource(GenServer.server(), String.Chars.t()) :: :ok | {:error, error()}
```

Drops a session resource and synchronizes the resulting snapshot.

# `events`

```elixir
@spec events(GenServer.server()) :: [map()]
```

Returns the bounded history of handled display events.

# `frame_token`

```elixir
@spec frame_token(GenServer.server(), pos_integer()) ::
  {:ok, non_neg_integer()} | {:error, term()}
```

Returns the latest completed display frame generation for a window.

# `info`

```elixir
@spec info(GenServer.server()) :: map()
```

Returns stable runtime topology and synchronization information.

# `inject_event`

```elixir
@spec inject_event(GenServer.server(), map()) :: {:ok, term()} | {:error, error()}
```

Injects an event into the active display queue without dispatching it immediately.

# `open_window`

```elixir
@spec open_window(GenServer.server(), GPUI.WindowSpec.t()) ::
  {:ok, pos_integer(), GPUI.Snapshot.t()}
  | {:error, GPUI.Session.topology_error()}
```

Adds a keyed declarative window and synchronizes it to the display.

# `put_resource`

```elixir
@spec put_resource(GenServer.server(), String.Chars.t(), map()) ::
  :ok | {:error, error()}
```

Stores a session resource and synchronizes the resulting snapshot.

# `refresh`

```elixir
@spec refresh(GenServer.server()) :: {:ok, GPUI.Snapshot.t()} | {:error, error()}
```

Rerenders every window from its current module and assigns, then synchronizes the display.

# `request_frame`

```elixir
@spec request_frame(GenServer.server()) :: :ok | {:error, error()}
```

Requests a display frame for the current snapshot without changing application state.

# `send_view`

```elixir
@spec send_view(GenServer.server(), pos_integer(), term()) ::
  {:ok, GPUI.Snapshot.t()} | {:error, error()}
```

Delivers an OTP message to a window's root view and synchronizes the display.

# `snapshot`

```elixir
@spec snapshot(GenServer.server()) :: {:ok, GPUI.Snapshot.t()} | {:error, error()}
```

Returns the current authoritative session snapshot.

# `snapshot!`

```elixir
@spec snapshot!(GenServer.server()) :: GPUI.Snapshot.t()
```

Returns the current authoritative session snapshot or raises when rendering fails.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

Starts a runtime linked to the caller.

# `subscribe`

```elixir
@spec subscribe(GenServer.server()) :: :ok
```

Subscribes the calling process to synchronized runtime updates.

# `unsubscribe`

```elixir
@spec unsubscribe(GenServer.server()) :: :ok
```

Unsubscribes the calling process from runtime updates.

# `windows`

```elixir
@spec windows(GenServer.server()) :: [GPUI.WindowSpec.t()]
```

Returns the runtime session's declarative windows.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
