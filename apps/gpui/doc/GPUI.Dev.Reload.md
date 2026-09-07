# `GPUI.Dev.Reload`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/dev/reload.ex#L1)

Development-time source reloading for a running GPUI runtime.

`watch/2` watches explicitly listed Elixir source files, recompiles a changed
file, and asks the runtime to render its existing windows again. Window
assigns remain authoritative, so ordinary `render/1`, `handle_event/3`, and
`handle_info/2` edits take effect without reopening the native window.

A watcher may receive a `:notify` PID. After every attempted file reload it
receives `{:gpui_reload, watcher, path, {:ok, modules}}` or
`{:gpui_reload, watcher, path, {:error, reason}}`. Files are parsed before
compilation so syntax failures cannot unload or partially redefine the live
root module.

This facility is intended for trusted local development source. It requires
the optional `:file_system` dependency; applications that do not use source
reload do not need to start or include it. The watcher does not reload native
code, remount applications, or migrate changed state shapes.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `wait`

```elixir
@spec wait(
  GenServer.server(),
  keyword()
) :: no_return()
```

Keeps an example alive and enables source reloading under `mix gpui.dev`.

# `watch`

```elixir
@spec watch(
  GenServer.server(),
  keyword()
) :: GenServer.on_start()
```

Starts a source watcher linked to the caller.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
