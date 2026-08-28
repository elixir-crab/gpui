defmodule GPUI.Schema.Core do
  @moduledoc """
  Neutral primitive declarations included by every native host.

  This explicit projection keeps host composition independent from the
  conventional component package while the coordinated protocol declarations
  remain versioned by `GPUI.Schema`.
  """

  @behaviour GPUI.Schema.Provider

  @component_tags ~w(viewport div button layer span scroll list item text_surface text_input img text)a
  @components Enum.map(@component_tags, &GPUI.Schema.component!/1)

  @impl true
  @doc "Returns neutral primitive declarations in protocol order."
  @spec components() :: [GPUI.Schema.Component.t()]
  def components, do: @components
end
