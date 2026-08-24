defmodule GPUI.Schema.Component do
  @moduledoc "Declarative schema for one renderer-native element or UI component."

  @enforce_keys [:tag, :kind]
  defstruct [
    :tag,
    :kind,
    events: [],
    required_events: [],
    attrs: [],
    children: false,
    stateful: false,
    public_required_attrs: [],
    public_hidden_attrs: [],
    public_slots: []
  ]

  @type scalar_type ::
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

  @type attr_type ::
          scalar_type()
          | {:enum, [String.t()]}
          | {:enum_list, [String.t()]}
          | {:default, scalar_type()}
          | {:default, scalar_type() | {:enum, [String.t()]}, term()}
          | {:default, {:enum_list, [String.t()]}, term()}

  @type t :: %__MODULE__{
          tag: atom(),
          kind: atom(),
          events: keyword(atom()),
          required_events: [atom()],
          attrs: keyword(attr_type()),
          children: boolean(),
          stateful: boolean(),
          public_required_attrs: [atom()],
          public_hidden_attrs: [atom()],
          public_slots: [{atom(), :required | :optional | :one_or_more}]
        }

  @doc "Returns whether a schema component exists only for renderer orchestration."
  @spec renderer_internal?(t()) :: boolean()
  def renderer_internal?(%__MODULE__{kind: :viewport}), do: true
  def renderer_internal?(%__MODULE__{}), do: false
end
