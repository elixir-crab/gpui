defmodule GPUI.Tree do
  @moduledoc "Renderer-independent queries over `GPUI.Element` and serialized element trees."

  alias GPUI.Element

  @type element_node :: Element.t() | map()
  @type selector :: keyword()

  @doc "Returns all nodes in depth-first order."
  @spec walk(element_node()) :: [element_node()]
  def walk(%Element{children: children} = node), do: [node | Enum.flat_map(children, &walk/1)]
  def walk(%{type: _type} = node), do: [node | node |> children() |> Enum.flat_map(&walk/1)]
  def walk(_leaf), do: []

  @doc "Returns every node matching a selector."
  @spec all(element_node(), selector()) :: [element_node()]
  def all(tree, selector) when is_list(selector),
    do: Enum.filter(walk(tree), &matches?(&1, selector))

  @doc "Returns the first matching node, or nil."
  @spec find(element_node(), selector()) :: element_node() | nil
  def find(tree, selector) when is_list(selector), do: tree |> all(selector) |> List.first()

  @doc "Returns the first matching node or raises."
  @spec find!(element_node(), selector()) :: element_node()
  def find!(tree, selector) when is_list(selector) do
    find(tree, selector) || raise ArgumentError, "no GPUI element matches #{inspect(selector)}"
  end

  @doc "Returns the root-to-node path for the first match."
  @spec path(element_node(), selector()) :: [element_node()] | nil
  def path(tree, selector) when is_list(selector), do: find_path(tree, selector, [])

  @doc false
  def matches?(%Element{type: type, attrs: attrs}, selector),
    do: matches_attributes?(type, Map.new(attrs), selector)

  def matches?(%{type: type} = node, selector),
    do: matches_attributes?(type, Map.new(Map.get(node, :attrs, %{})), selector)

  defp matches_attributes?(type, attrs, selector) do
    Enum.all?(selector, fn
      {:type, expected} -> type == expected
      {key, expected} -> Map.get(attrs, key) == expected
    end)
  end

  defp find_path(%Element{} = node, selector, ancestors),
    do: find_node_path(node, selector, ancestors)

  defp find_path(%{type: _type} = node, selector, ancestors),
    do: find_node_path(node, selector, ancestors)

  defp find_path(_leaf, _selector, _ancestors), do: nil

  defp find_node_path(node, selector, ancestors) do
    path = ancestors ++ [node]

    if matches?(node, selector),
      do: path,
      else: Enum.find_value(children(node), &find_path(&1, selector, path))
  end

  defp children(%Element{children: children}), do: children
  defp children(node), do: Map.get(node, :children, [])
end
