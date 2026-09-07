# `GPUI.Schema.Component`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/schema/component.ex#L1)

Declarative schema for one renderer-native element or UI component.

# `attr_type`

```elixir
@type attr_type() ::
  scalar_type()
  | {:enum, [String.t()]}
  | {:enum_list, [String.t()]}
  | {:default, scalar_type()}
  | {:default, scalar_type() | {:enum, [String.t()]}, term()}
  | {:default, {:enum_list, [String.t()]}, term()}
```

# `scalar_type`

```elixir
@type scalar_type() ::
  :string
  | :accessibility_label
  | :accessibility_description
  | :accessibility_value
  | :accessibility_checked
  | :required_string
  | :number
  | :non_negative_number
  | :positive_number
  | :unit_number
  | :edge_fade_size
  | :layer_priority
  | :non_negative_integer
  | :positive_integer
  | :boolean
  | :string_list
  | :select_options
  | :radio_options
  | :resource
  | :text_buffer
  | :text_ranges
  | :text_position
  | :text_decorations
  | :text_inline_projections
  | :text_block_projections
  | :paint_commands
```

# `t`

```elixir
@type t() :: %GPUI.Schema.Component{
  attrs: keyword(attr_type()),
  children: boolean(),
  events: keyword(atom()),
  extension: GPUI.Schema.Extension.t() | nil,
  kind: atom(),
  public_hidden_attrs: [atom()],
  public_required_attrs: [atom()],
  public_slots: [{atom(), :required | :optional | :one_or_more}],
  required_events: [atom()],
  stateful: boolean(),
  tag: atom()
}
```

# `renderer_internal?`

```elixir
@spec renderer_internal?(t()) :: boolean()
```

Returns whether a schema component exists only for renderer orchestration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
