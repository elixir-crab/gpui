defmodule GPUI.Schema.Style do
  @moduledoc false

  @enforce_keys [:name, :field, :type]
  defstruct [:name, :field, :type, :render]

  @type render ::
          :flex_if_true
          | {:enum_methods, [{String.t(), atom()}]}
          | {:option_method, atom(), :rgb | :px}

  @type t :: %__MODULE__{
          name: atom(),
          field: atom(),
          type: atom() | {atom(), atom()},
          render: render() | nil
        }
end
