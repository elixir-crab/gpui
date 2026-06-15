defmodule GPUI.WindowSpec do
  @moduledoc """
  Declarative window specification returned by the application DSL.
  """

  @type root :: {module(), map() | keyword()}
  @type t :: %__MODULE__{
          title: String.t(),
          size: {pos_integer(), pos_integer()} | nil,
          root: root() | nil
        }

  defstruct [:title, :size, :root]
end
