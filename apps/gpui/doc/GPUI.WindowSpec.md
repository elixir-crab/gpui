# `GPUI.WindowSpec`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/window_spec.ex#L1)

Declarative window specification returned by the application DSL.

Each window owns a bounded set of platform-aware `GPUI.Command` bindings in
addition to its title, size, and root view.

# `chrome`

```elixir
@type chrome() :: :system | :content
```

# `key`

```elixir
@type key() :: String.t()
```

# `root`

```elixir
@type root() :: {module(), map() | keyword()}
```

# `t`

```elixir
@type t() :: %GPUI.WindowSpec{
  chrome: chrome(),
  commands: [GPUI.Command.t()],
  id: pos_integer() | nil,
  key: key() | nil,
  min_size: {pos_integer(), pos_integer()} | nil,
  resizable: boolean(),
  root: root() | nil,
  size: {pos_integer(), pos_integer()} | nil,
  title: String.t()
}
```

# `new`

```elixir
@spec new(
  String.t(),
  keyword()
) :: t()
```

Builds and validates a declarative window specification.

# `validate!`

```elixir
@spec validate!(t()) :: t()
```

Validates a declarative window specification and returns it.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
