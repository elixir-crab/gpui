# `GPUI.Tree`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/tree.ex#L1)

Renderer-independent queries over `GPUI.Element` and serialized element trees.

# `element_node`

```elixir
@type element_node() :: GPUI.Element.t() | map()
```

# `selector`

```elixir
@type selector() :: keyword()
```

# `all`

```elixir
@spec all(element_node(), selector()) :: [element_node()]
```

Returns every node matching a selector.

# `find`

```elixir
@spec find(element_node(), selector()) :: element_node() | nil
```

Returns the first matching node, or nil.

# `find!`

```elixir
@spec find!(element_node(), selector()) :: element_node()
```

Returns the first matching node or raises.

# `matches?`

```elixir
@spec matches?(element_node(), selector()) :: boolean()
```

Returns whether an element node matches every selector attribute.

# `path`

```elixir
@spec path(element_node(), selector()) :: [element_node()] | nil
```

Returns the root-to-node path for the first match.

# `walk`

```elixir
@spec walk(element_node()) :: [element_node()]
```

Returns all nodes in depth-first order.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
