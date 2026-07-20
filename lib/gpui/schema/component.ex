defmodule GPUI.Schema.Component do
  @moduledoc false

  @enforce_keys [:tag, :kind]
  defstruct [:tag, :kind, events: [], attrs: [], children: false, stateful: false]

  @type scalar_type ::
          :string
          | :number
          | :positive_number
          | :non_negative_integer
          | :positive_integer
          | :boolean
          | :string_list
          | :select_options
          | :radio_options
          | :resource

  @type attr_type ::
          scalar_type()
          | {:enum, [String.t()]}
          | {:default, scalar_type()}
          | {:default, scalar_type() | {:enum, [String.t()]}, term()}

  @type t :: %__MODULE__{
          tag: atom(),
          kind: atom(),
          events: keyword(atom()),
          attrs: keyword(attr_type()),
          children: boolean(),
          stateful: boolean()
        }
end
