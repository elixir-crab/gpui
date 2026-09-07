# `GPUI.Snapshot`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/snapshot.ex#L1)

Renderer-independent snapshot of a running `GPUI.Session`.

Snapshots are the only state transferred from sessions to local or remote
displays.

# `t`

```elixir
@type t() :: %GPUI.Snapshot{
  resources: %{optional(String.t()) =&gt; map()},
  windows: [GPUI.Snapshot.Window.t()]
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
