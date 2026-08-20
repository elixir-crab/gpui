defmodule GPUI.Schema.Resource do
  @moduledoc "Declarative schema for one renderer resource kind."

  @enforce_keys [:name, :fields]
  defstruct [:name, :fields]

  @type field_type ::
          :u32
          | :string
          | :atom
          | :binary
          | {:field, atom(), field_type()}
          | {:option, field_type()}
          | {:default, :atom_string, String.t()}

  @type t :: %__MODULE__{name: atom(), fields: keyword(field_type())}
end
