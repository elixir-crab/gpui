defmodule GPUI.Schema.Component do
  @moduledoc false

  @enforce_keys [:tag, :kind]
  defstruct [:tag, :kind, events: [], attrs: []]

  @type t :: %__MODULE__{
          tag: atom(),
          kind: atom(),
          events: keyword(atom()),
          attrs: keyword(atom())
        }
end
