defmodule GPUI.ComponentSpec.Style do
  @moduledoc false

  @enforce_keys [:name, :field, :type]
  defstruct [:name, :field, :type]

  @type t :: %__MODULE__{name: atom(), field: atom(), type: atom() | {atom(), atom()}}
end
