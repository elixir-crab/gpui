# `GPUI.Builder`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/builder.ex#L1)

Programmatic builders for immutable `GPUI.Element` trees.

Most views use the `~GPUI` template sigil. Import this module explicitly when
pipe-style construction is a better fit for generated or data-driven trees.

# `bg`

```elixir
@spec bg(GPUI.Element.t(), term()) :: GPUI.Element.t()
```

Sets background color.

# `child`

```elixir
@spec child(GPUI.Element.t(), GPUI.Element.child()) :: GPUI.Element.t()
```

Adds a child to an element for pipe-style view construction.

# `div`
*macro* 

Creates a `div` element.

# `div`
*macro* 

# `div`
*macro* 

# `flex`

```elixir
@spec flex(GPUI.Element.t()) :: GPUI.Element.t()
```

Adds flex display style to an element.

# `flex_col`

```elixir
@spec flex_col(GPUI.Element.t()) :: GPUI.Element.t()
```

Adds column flex direction to an element.

# `items_center`

```elixir
@spec items_center(GPUI.Element.t()) :: GPUI.Element.t()
```

Centers children on the cross axis.

# `justify_center`

```elixir
@spec justify_center(GPUI.Element.t()) :: GPUI.Element.t()
```

Centers children on the main axis.

# `px`

```elixir
@spec px(number()) :: {:px, float()}
```

Represents a GPUI pixel length.

# `rgb`

```elixir
@spec rgb(non_neg_integer()) :: {:rgb, non_neg_integer()}
```

Represents a GPUI RGB color.

# `size`

```elixir
@spec size(GPUI.Element.t(), term()) :: GPUI.Element.t()
```

Sets width and height to the same value.

# `style`

```elixir
@spec style(GPUI.Element.t(), atom(), term()) :: GPUI.Element.t()
```

Sets a schema-backed style on an element.

# `text`
*macro* 

Creates a text node.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
