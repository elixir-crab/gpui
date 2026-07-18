defmodule GPUI.Schema.Style do
  @moduledoc false

  @enforce_keys [:name, :field, :type]
  defstruct [:name, :field, :type, :render]

  @type value_type ::
          :atom_string | :rgb | :number | :px | :radius | {:atom_eq, atom()}

  @type render ::
          :flex_if_true
          | {:enum_methods, [{String.t(), atom()}]}
          | {:enum_values, atom(), [{String.t(), [atom()]}]}
          | {:option_method, atom(), :rgb | :px | :f32}

  @type t :: %__MODULE__{
          name: atom(),
          field: atom(),
          type: value_type(),
          render: render() | nil
        }
end
