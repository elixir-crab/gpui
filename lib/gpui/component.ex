defmodule GPUI.Component do
  @moduledoc """
  Helpers for HEEx-style GPUI component tags.
  """

  alias GPUI.Element

  @type component_type :: :remote_component | :local_component

  @doc false
  @spec assigns(keyword(), [Element.child()]) :: map()
  def assigns(attrs, children) when is_list(attrs) and is_list(children) do
    attrs
    |> Map.new()
    |> Map.put(:children, children)
  end

  @doc false
  @spec fallback(component_type(), String.t(), keyword(), [Element.child()]) :: Element.t()
  def fallback(:remote_component, name, attrs, children) do
    %Element{type: :component, attrs: [component: name] ++ attrs, children: children}
  end

  def fallback(:local_component, name, attrs, children) do
    %Element{type: :component, attrs: [component: ".#{name}"] ++ attrs, children: children}
  end
end
