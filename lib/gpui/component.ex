defmodule GPUI.Component do
  @moduledoc """
  Helpers for HEEx-style GPUI component tags.
  """

  alias GPUI.Element

  @doc false
  @spec assigns(keyword(), [Element.child()]) :: map()
  def assigns(attrs, children) when is_list(attrs) and is_list(children) do
    attrs
    |> Map.new()
    |> Map.put(:children, children)
  end
end
