defmodule GPUI.Schema.Extension do
  @moduledoc "Compile-time metadata for one versioned renderer presentation contract."

  @enforce_keys [:id, :version, :capabilities]
  defstruct [:id, :version, :capabilities]

  @type t :: %__MODULE__{
          id: atom(),
          version: pos_integer(),
          capabilities: [atom()]
        }
end
