# `GPUI.Schema`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/schema.ex#L1)

Canonical element, component, event, resource, and style protocol schema.

# `apply_defaults`

# `component!`

# `component_options_doc`

```elixir
@spec component_options_doc(atom()) :: String.t()
```

Returns generated public option documentation for a component tag.

# `components`

# `defaults`

# `define_component_option_types`
*macro* 

Defines public component option types from schema definitions.

# `events`

# `extension`

```elixir
@spec extension(atom()) :: GPUI.Schema.Extension.t()
```

Returns one schema-owned presentation contract by ID.

# `extensions`

```elixir
@spec extensions() :: [GPUI.Schema.Extension.t()]
```

Returns all schema-owned versioned presentation contracts.

# `identified_tags`

# `native_tags`

Returns every renderer-native schema tag in declaration order.

# `registry`

```elixir
@spec registry() :: GPUI.Schema.Registry.t()
```

Returns an immutable registry containing neutral core declarations.

# `registry`

```elixir
@spec registry([module()]) :: GPUI.Schema.Registry.t()
```

Returns a composed registry for explicitly selected schema modules.

# `resource_specs`

# `resources`

# `stateful_components`

# `style_specs`

# `styles`

# `tags`

# `validate_component_assigns!`

```elixir
@spec validate_component_assigns!(map(), atom() | GPUI.Schema.Component.t(), [atom()]) ::
  map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
