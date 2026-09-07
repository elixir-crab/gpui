# `GPUI.Snapshot.Window`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/snapshot/window.ex#L1)

Typed shape of one serialized window in a `GPUI.Snapshot`.

Window snapshots remain plain maps so they can cross local and remote display
boundaries without conversion. This module supplies named map types for that
stable in-process contract.

# `root`

```elixir
@type root() :: %{module: String.t(), assigns: map(), tree: map()}
```

# `t`

```elixir
@type t() :: %{
  id: pos_integer(),
  key: String.t() | nil,
  title: String.t(),
  size: [pos_integer()],
  min_size: [pos_integer()] | nil,
  resizable: boolean(),
  chrome: GPUI.WindowSpec.chrome(),
  lifecycle: [GPUI.View.window_event()],
  commands: [{String.t(), String.t()}],
  root: root() | nil
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
