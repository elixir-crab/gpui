defmodule GPUI.Schema.Style do
  @moduledoc "Declarative schema for one renderer-independent style property."

  @enforce_keys [:name, :field, :type]
  defstruct [:name, :field, :type, :render]

  @type value_type ::
          :atom_string
          | :rgb
          | :number
          | :px
          | :length
          | :position_length
          | :flex_basis
          | :radius
          | {:atom_eq, atom()}

  @type render ::
          :flex_if_true
          | {:enum_methods, [{String.t(), atom()}]}
          | {:enum_values, atom(), [{String.t(), [atom()]}]}
          | {:option_method, atom(), :rgb | :px | :length | :position_length | :flex_basis | :f32}
          | {:option_methods, [atom()], :position_length}

  @type t :: %__MODULE__{
          name: atom(),
          field: atom(),
          type: value_type(),
          render: render() | nil
        }
end
