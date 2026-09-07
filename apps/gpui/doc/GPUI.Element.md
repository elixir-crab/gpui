# `GPUI.Element`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/element.ex#L1)

Serializable element tree produced by `GPUI.View` modules.

# `child`

```elixir
@type child() :: t() | primitive()
```

# `primitive`

```elixir
@type primitive() :: String.t() | number() | atom()
```

# `t`

```elixir
@type t() :: %GPUI.Element{attrs: keyword(), children: [child()], type: atom()}
```

# `append_child`

```elixir
@spec append_child(t(), child()) :: t()
```

Appends one child to an immutable element value.

# `put_style`

```elixir
@spec put_style(t(), atom(), term()) :: t()
```

Adds or replaces one explicit style value on an immutable element.

# `to_payload`

```elixir
@spec to_payload(t() | child()) :: map() | String.t()
```

Converts an element tree into plain serializable maps/lists.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
