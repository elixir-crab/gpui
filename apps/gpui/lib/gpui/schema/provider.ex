defmodule GPUI.Schema.Provider do
  @moduledoc """
  Contract for a statically composed declarative schema provider.

  Implementing this behaviour does not register a provider at runtime. A native
  host must include the provider explicitly and link an implementation for every
  native requirement used by its declarations.
  """

  @callback components() :: [GPUI.Schema.Component.t()]
end
