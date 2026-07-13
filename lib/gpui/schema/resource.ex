defmodule GPUI.Schema.Resource do
  @moduledoc false

  @enforce_keys [:name, :fields]
  defstruct [:name, :fields]

  @type t :: %__MODULE__{name: atom(), fields: keyword(atom())}
end
