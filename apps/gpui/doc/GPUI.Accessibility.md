# `GPUI.Accessibility`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/accessibility.ex#L1)

Bounded renderer-independent accessibility contracts for generic elements.

Semantic native components own their roles and state policy. This module
validates explicit metadata on generic primitives before it crosses a display
or transport boundary.

# `checked`

```elixir
@type checked() :: boolean() | :mixed
```

# `interaction`

```elixir
@type interaction() :: :structural | :activate | :composite | :value
```

# `role`

```elixir
@type role() :: String.t()
```

# `role_spec`

```elixir
@type role_spec() :: {atom(), %{gpui: atom(), interaction: interaction()}}
```

# `state_rule`

```elixir
@type state_rule() :: {atom(), [String.t()]}
```

# `attrs`

```elixir
@spec attrs() :: keyword(GPUI.Schema.Component.attr_type())
```

Returns generic accessibility attributes accepted by schema containers.

# `metadata?`

```elixir
@spec metadata?(map()) :: boolean()
```

Returns whether an attribute map contains generic accessibility metadata.

# `role_specs`

```elixir
@spec role_specs() :: [role_spec()]
```

Returns role specifications used by validation and native code generation.

# `roles`

```elixir
@spec roles() :: [String.t()]
```

Returns the closed generic accessibility role vocabulary.

# `state_roles`

```elixir
@spec state_roles() :: [state_rule()]
```

Returns accessibility state-to-role validation rules.

# `validate_generic!`

```elixir
@spec validate_generic!(atom(), map()) :: map()
```

Validates generic accessibility metadata for one supported element tag.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
