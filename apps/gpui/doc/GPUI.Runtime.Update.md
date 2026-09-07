# `GPUI.Runtime.Update`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/runtime/update.ex#L1)

A synchronized runtime update delivered to `GPUI.Runtime` subscribers.

`revision` increases monotonically within one runtime. `events` contains the
normalized events handled to produce `snapshot`.

# `t`

```elixir
@type t() :: %GPUI.Runtime.Update{
  events: [GPUI.Event.payload()],
  revision: pos_integer(),
  snapshot: GPUI.Snapshot.t()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
