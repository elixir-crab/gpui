defmodule GPUI.WindowSpec do
  @moduledoc """
  Declarative window specification returned by the application DSL.
  """

  @type root :: {module(), map() | keyword()}
  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          title: String.t(),
          size: {pos_integer(), pos_integer()} | nil,
          root: root() | nil
        }

  defstruct [:id, :title, :size, :root]
end
