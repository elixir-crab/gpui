defmodule GPUI.Schema.Extension do
  @moduledoc "Compile-time metadata for one versioned renderer presentation contract."

  @max_capabilities 64

  @enforce_keys [:id, :version, :capabilities]
  defstruct [:id, :version, :capabilities]

  @type t :: %__MODULE__{
          id: atom(),
          version: pos_integer(),
          capabilities: [atom()]
        }

  @doc "Maximum capabilities declared or advertised for one extension version."
  @spec max_capabilities() :: pos_integer()
  def max_capabilities, do: @max_capabilities
end
