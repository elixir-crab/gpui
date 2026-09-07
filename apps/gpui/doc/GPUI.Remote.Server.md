# `GPUI.Remote.Server`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/remote/server.ex#L1)

SafeRPC endpoint for renderer-independent GPUI application sessions.

Every remote session owns a distinct `GPUI.Session`. The server never starts a
native display; rendering happens only on the connected display client.

## Options

  * `:app` - required `GPUI.Application` module;
  * `:args` - default mount argument used when a client omits one;
  * `:port` - listening port, defaulting to `0` for an OS-assigned port;
  * `:ssl` - `false` or TLS listener options;
  * `:session_ttl` - inactivity timeout in milliseconds or `:infinity`,
    defaulting to 30 minutes;
  * `:max_in_flight_requests_per_connection` - positive limit up to 4,096,
    defaulting to 64;
  * `:max_in_flight_requests_per_session` - positive limit up to 4,096,
    defaulting to 16;
  * `:name` - optional supervisor name.

# `child_spec`

```elixir
@spec child_spec(keyword()) :: Supervisor.child_spec()
```

Builds the remote server supervision-tree child specification.

# `coordinator`

Finds the coordinator process belonging to a remote server tree.

# `port`

```elixir
@spec port(Supervisor.supervisor()) :: {:ok, :inet.port_number()} | {:error, term()}
```

Returns the server's effective listening port.

# `start_coordinator`

Starts the internal remote-server coordinator process.

# `start_link`

```elixir
@spec start_link(keyword()) :: Supervisor.on_start()
```

Starts the remote server supervision tree linked to the caller.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
