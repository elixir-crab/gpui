defmodule GPUI.Schema.Component do
  @moduledoc false

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
          | :required_string
          | :number
          | :positive_number
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

  @type attr_type ::
          scalar_type()
          | {:enum, [String.t()]}
          | {:default, scalar_type()}
          | {:default, scalar_type() | {:enum, [String.t()]}, term()}

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

  @doc false
  @spec renderer_internal?(t()) :: boolean()
  def renderer_internal?(%__MODULE__{kind: :viewport}), do: true
  def renderer_internal?(%__MODULE__{}), do: false
end
