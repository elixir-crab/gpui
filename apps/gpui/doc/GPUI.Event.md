# `GPUI.Event`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/event.ex#L1)

Normalized UI event delivered from a display into `GPUI.Session`.

# `payload`

```elixir
@type payload() :: %{
  :type =&gt; type(),
  :window_id =&gt; pos_integer(),
  optional(:event) =&gt; String.t(),
  optional(:value) =&gt; term(),
  optional(atom()) =&gt; term()
}
```

# `t`

```elixir
@type t() :: %GPUI.Event{
  attrs: map(),
  event: String.t() | nil,
  type: type(),
  value: term(),
  window_id: pos_integer() | nil
}
```

# `type`

```elixir
@type type() ::
  :click
  | :command
  | :change
  | :select
  | :release
  | :search
  | :submit
  | :range
  | :link
  | :transaction
  | :selection
  | :viewport
  | :geometry
  | :range_geometry
  | :hit_test
  | :bounds
  | :focus
  | :blur
  | :keydown
  | :keyup
  | :drag_enter
  | :drag_move
  | :drag_leave
  | :drop
  | :clipboard
  | :clipboard_write
  | :copy
  | :file_read
  | :window_close_request
  | :window_focus
  | :window_blur
  | :window_closed
```

# `injectable_types`

```elixir
@spec injectable_types() :: [type()]
```

Returns event types accepted by the low-level native injection boundary.

# `is_routed_type`
*macro* 

# `normalize`

```elixir
@spec normalize(t() | map() | keyword()) :: {:ok, payload()} | {:error, term()}
```

# `routed_types`

```elixir
@spec routed_types() :: [type()]
```

Returns the renderer-independent event types routed to root view callbacks.

# `to_map`

```elixir
@spec to_map(t()) :: payload()
```

Converts an event struct and its extra attributes into a plain event map.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
