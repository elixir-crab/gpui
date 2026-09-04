defmodule GPUI.UI.Collection do
  @moduledoc """
  Typed helpers for correlated source-backed collection options.

  The helpers return ordinary maps so they compose naturally with component
  assigns while keeping source, selection, and reveal invariants together.
  """

  alias GPUI.UI.Collection.{Selection, Source}

  @doc "Merges a loaded source window into existing component assigns."
  @spec source(map(), Source.t()) :: map()
  def source(assigns, %Source{} = source) when is_map(assigns),
    do: Map.merge(assigns, Source.assigns(source))

  @doc "Merges controlled selection identity into existing component assigns."
  @spec selected(map(), Selection.t()) :: map()
  def selected(assigns, %Selection{} = selection) when is_map(assigns),
    do: Map.merge(assigns, Selection.assigns(selection, :selected))

  @doc "Merges controlled reveal identity into existing component assigns."
  @spec reveal(map(), Selection.t()) :: map()
  def reveal(assigns, %Selection{} = selection) when is_map(assigns),
    do: Map.merge(assigns, Selection.assigns(selection, :reveal))
end
