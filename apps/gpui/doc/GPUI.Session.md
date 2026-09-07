# `GPUI.Session`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/session.ex#L1)

Renderer-independent state engine for one running `GPUI.Application`.

A session owns declarative windows, root-view assigns, rendered snapshots,
resources, strict event dispatch, and atomic callback transitions. It has no
knowledge of native GPUI, displays, or network transports.

Ordinary applications should use `GPUI.Runtime`, which composes this state
engine with a display and synchronization lifecycle. Direct session use is an
advanced infrastructure boundary for remote hosting, custom runtimes, and
renderer-independent protocol integration.

# `operation_error`

```elixir
@type operation_error() ::
  {:render_failed, term(), Exception.stacktrace()}
  | {:callback_failed, module(), atom(), term(), Exception.stacktrace()}
  | {:invalid_callback_return, module(), atom(), term()}
```

# `snapshot`

```elixir
@type snapshot() :: GPUI.Snapshot.t()
```

# `state`

```elixir
@type state() :: %{
  windows: [GPUI.WindowSpec.t()],
  resources: %{optional(String.t()) =&gt; map()},
  next_window_id: pos_integer()
}
```

# `topology_error`

```elixir
@type topology_error() ::
  :duplicate_window_key
  | :window_not_found
  | :window_limit_reached
  | {:too_many_windows, pos_integer()}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `close_window`

```elixir
@spec close_window(GenServer.server(), GPUI.WindowSpec.key() | pos_integer()) ::
  {:ok, snapshot()} | {:error, topology_error()}
```

Removes one declarative window by stable key or native session ID.

# `dispatch_event`

```elixir
@spec dispatch_event(GenServer.server(), map()) ::
  {:ok, map(), snapshot()} | {:error, operation_error()}
```

Validates and dispatches one display event, returning the handled fact and current snapshot.

# `dispatch_events`

```elixir
@spec dispatch_events(GenServer.server(), [map()]) ::
  {:ok, [map()], snapshot()} | {:error, operation_error()}
```

Validates and dispatches display events in order, returning handled facts and current snapshot.

# `drop_resource`

```elixir
@spec drop_resource(GenServer.server(), String.Chars.t()) :: :ok
```

Removes one renderer-independent resource from the next snapshot.

# `open_window`

```elixir
@spec open_window(GenServer.server(), GPUI.WindowSpec.t()) ::
  {:ok, pos_integer(), snapshot()} | {:error, topology_error()}
```

Adds a keyed declarative window without remounting the application.

# `put_resource`

```elixir
@spec put_resource(GenServer.server(), String.Chars.t(), map()) :: :ok
```

Stores one renderer-independent resource in the next snapshot.

# `refresh`

```elixir
@spec refresh(GenServer.server()) :: {:ok, snapshot()} | {:error, term()}
```

Rerenders every window with its current module and assigns.

# `send_view`

```elixir
@spec send_view(GenServer.server(), pos_integer(), term()) ::
  {:ok, snapshot()}
  | {:error, :window_not_found | topology_error() | operation_error()}
```

Delivers an OTP message to a window's root view.

# `snapshot`

```elixir
@spec snapshot(GenServer.server()) :: {:ok, snapshot()} | {:error, operation_error()}
```

Returns the current authoritative renderer-independent snapshot.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

Starts the renderer-independent state engine linked to the caller.

# `windows`

```elixir
@spec windows(GenServer.server()) :: [GPUI.WindowSpec.t()]
```

Returns the session's declarative windows.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
