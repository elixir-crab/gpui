defmodule GPUI.Schema.Surfaces do
  @moduledoc """
  Neutral specialized surfaces implemented directly with vanilla GPUI.

  Their current convenience builders may live in `gpui_components`, but their
  wire declarations and native capability do not require `gpui-component`.
  """

  @behaviour GPUI.Schema.Provider

  @component_tags ~w(ui_edge_fade ui_frost ui_paint)a
  @components Enum.map(@component_tags, &GPUI.Schema.component!/1)

  @impl true
  @doc "Returns neutral specialized-surface declarations in protocol order."
  @spec components() :: [GPUI.Schema.Component.t()]
  def components, do: @components
end
