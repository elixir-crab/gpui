# `GPUI.Debug`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/debug.ex#L1)

Renderer-independent inspection of authoritative GPUI snapshots and trees.

# `format_tree`

```elixir
@spec format_tree(
  GenServer.server() | GPUI.Snapshot.t() | map(),
  keyword()
) :: String.t()
```

Formats a bounded, human-readable tree.

# `print_tree`

Prints a bounded tree and returns the original source.

# `tree`

```elixir
@spec tree(
  GenServer.server() | GPUI.Snapshot.t() | map(),
  keyword()
) :: map()
```

Returns a window's authoritative element tree. Runtime render failures raise `GPUI.Runtime.Error`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
