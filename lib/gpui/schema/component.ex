defmodule GPUI.Schema.Component do
  @moduledoc false

  @enforce_keys [:tag, :kind]
  defstruct [:tag, :kind, events: [], attrs: [], children: false, stateful: false]

  @type t :: %__MODULE__{
          tag: atom(),
          kind: atom(),
          events: keyword(atom()),
          attrs: keyword(atom()),
          children: boolean(),
          stateful: boolean()
        }
end
