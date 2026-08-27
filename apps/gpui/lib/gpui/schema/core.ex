defmodule GPUI.Schema.Core do
  @moduledoc """
  Neutral primitive declarations included by every native host.

  This explicit projection keeps host composition independent from the
  conventional component package while the coordinated protocol declarations
  remain versioned by `GPUI.Schema`.
  """

  @components GPUI.Schema.components()
              |> Enum.reject(&String.starts_with?(Atom.to_string(&1.tag), "ui_"))

  @doc "Returns neutral primitive declarations in protocol order."
  @spec components() :: [GPUI.Schema.Component.t()]
  def components, do: @components
end
