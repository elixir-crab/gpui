defmodule GPUI.Test.UI do
  @moduledoc """
  An opaque interactive UI handle supplied by `use GPUI.Test, native: ...`.

  Pass this value to the interaction helpers imported by `GPUI.Test`.
  """

  @enforce_keys [:pid, :ref]
  defstruct [:pid, :ref]

  @type t :: %__MODULE__{pid: pid(), ref: reference()}
end
