# `GPUI.Schema.Registry`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/schema/registry.ex#L1)

Immutable composition of explicitly selected declarative schema modules.

A registry is assembled by the framework or maintainer tooling from known
modules. It is not a runtime plugin registry and does not accept renderer
callbacks or opaque native payloads.

# `provider_entry`

```elixir
@type provider_entry() :: %{
  provider: schema_module(),
  component: GPUI.Schema.Component.t()
}
```

# `schema_module`

```elixir
@type schema_module() :: module()
```

# `t`

```elixir
@type t() :: %GPUI.Schema.Registry{
  components: [GPUI.Schema.Component.t()],
  modules: [schema_module()]
}
```

# `component!`

```elixir
@spec component!(t(), atom()) :: GPUI.Schema.Component.t()
```

Returns one component from the composed registry.

# `components`

```elixir
@spec components(t()) :: [GPUI.Schema.Component.t()]
```

Returns the composed components in declaration order.

# `entries`

```elixir
@spec entries(t()) :: [provider_entry()]
```

Returns provider/component entries in composed declaration order.

# `from_components`

```elixir
@spec from_components([GPUI.Schema.Component.t()]) :: t()
```

Builds an immutable registry directly from already-validated component declarations.

# `include`

```elixir
@spec include(t(), schema_module()) :: t()
```

Includes one explicit schema module and rejects duplicate tags.

# `native_tags`

```elixir
@spec native_tags(t()) :: [atom()]
```

Returns all composed native tags in declaration order.

# `new`

```elixir
@spec new() :: t()
```

Creates an empty immutable schema registry.

# `order`

```elixir
@spec order(t(), [atom()]) :: t()
```

Orders a complete registry by an explicit canonical tag manifest.

# `provider!`

```elixir
@spec provider!(t(), atom()) :: schema_module()
```

Returns the explicit provider module for one composed component.

# `stateful_components`

```elixir
@spec stateful_components(t()) :: [GPUI.Schema.Component.t()]
```

Returns the stateful components in declaration order.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
