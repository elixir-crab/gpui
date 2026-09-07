# `GPUI.Test.Display`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/test/display.ex#L1)

Deterministic in-memory display for session and runtime tests.

The display records synchronized snapshots and queues injected events without
starting the native renderer. Pass `owner: self()` to receive each sync as
`{:gpui_snapshot, snapshot}`.

# `state`

```elixir
@type state() :: %{
  events: [map()],
  snapshots: [GPUI.Snapshot.t()],
  owner: pid() | nil
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `latest_snapshot`

```elixir
@spec latest_snapshot(Agent.agent()) :: GPUI.Snapshot.t() | nil
```

Returns the most recently synchronized snapshot.

# `snapshots`

```elixir
@spec snapshots(Agent.agent()) :: [GPUI.Snapshot.t()]
```

Returns synchronized snapshots in chronological order.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
