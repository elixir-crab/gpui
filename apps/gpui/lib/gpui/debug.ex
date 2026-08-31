defmodule GPUI.Debug do
  @moduledoc "Renderer-independent inspection of authoritative GPUI snapshots and trees."

  alias GPUI.{Runtime, Snapshot}

  @doc "Returns a window's authoritative element tree."
  @spec tree(GenServer.server() | Snapshot.t() | map(), keyword()) :: map()
  def tree(source, opts \\ [])
  def tree(%Snapshot{} = snapshot, opts), do: window!(snapshot, opts).root.tree
  def tree(%{type: _type} = tree, _opts), do: tree
  def tree(runtime, opts), do: runtime |> Runtime.snapshot() |> tree(opts)

  @doc "Finds the first element matching the supplied selector."
  @spec find(GenServer.server() | Snapshot.t() | map(), keyword()) :: map() | nil
  def find(source, selector) when is_list(selector) do
    source |> tree() |> walk() |> Enum.find(&matches?(&1, selector))
  end

  @doc "Returns the root-to-element path for the first matching element."
  @spec path(GenServer.server() | Snapshot.t() | map(), keyword()) :: [map()] | nil
  def path(source, selector) when is_list(selector), do: find_path(tree(source), selector, [])

  @doc "Formats a bounded, human-readable tree."
  @spec format_tree(GenServer.server() | Snapshot.t() | map(), keyword()) :: String.t()
  def format_tree(source, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 24)
    max_children = Keyword.get(opts, :max_children, 100)
    format_node(tree(source, opts), 0, max_depth, max_children) |> IO.iodata_to_binary()
  end

  @doc "Prints a bounded tree and returns the original source."
  def print_tree(source, opts \\ []) do
    IO.puts(format_tree(source, opts))
    source
  end

  defp window!(snapshot, opts) do
    selector = Keyword.get(opts, :window, :first)

    window =
      case selector do
        :first ->
          List.first(snapshot.windows)

        id when is_integer(id) ->
          Enum.find(snapshot.windows, &(&1.id == id))

        value when is_binary(value) ->
          Enum.find(snapshot.windows, &(&1.title == value or &1.key == value))
      end

    window || raise ArgumentError, "snapshot window not found: #{inspect(selector)}"
  end

  defp walk(%{type: _type} = node),
    do: [node | Enum.flat_map(Map.get(node, :children, []), &walk/1)]

  defp walk(_leaf), do: []

  defp matches?(node, selector) do
    Enum.all?(selector, fn
      {:type, value} -> node.type == value
      {:id, value} -> attr(node, :id) == value
      {:label, value} -> attr(node, :label) == value
      {name, value} -> attr(node, name) == value
    end)
  end

  defp find_path(%{type: _type} = node, selector, ancestors) do
    path = ancestors ++ [node]

    if matches?(node, selector) do
      path
    else
      Enum.find_value(Map.get(node, :children, []), &find_path(&1, selector, path))
    end
  end

  defp find_path(_leaf, _selector, _ancestors), do: nil

  defp format_node(%{type: _type} = node, depth, max_depth, max_children) do
    line = [
      String.duplicate("  ", depth),
      if(depth == 0, do: "", else: "└─ "),
      summary(node),
      "\n"
    ]

    if depth >= max_depth do
      [line, String.duplicate("  ", depth + 1), "…\n"]
    else
      children = if node.type == :text, do: [], else: Map.get(node, :children, [])

      [
        line
        | children
          |> Enum.take(max_children)
          |> Enum.map(&format_node(&1, depth + 1, max_depth, max_children))
      ]
    end
  end

  defp format_node(leaf, depth, _max_depth, _max_children),
    do: [String.duplicate("  ", depth), "└─ ", inspect(leaf), "\n"]

  defp summary(node) do
    attrs = Map.get(node, :attrs, %{})
    id = if value = Map.get(attrs, :id), do: "##{value}", else: ""
    label = Map.get(attrs, :label) || text_summary(node)

    flags =
      Enum.filter(
        [
          flag(attrs, :selected),
          flag(attrs, :active),
          flag(attrs, :disabled),
          flag(attrs, :checked)
        ],
        & &1
      )

    [
      to_string(node.type),
      id,
      if(label, do: " #{inspect(label)}", else: ""),
      if(flags == [], do: "", else: " [#{Enum.join(flags, ", ")}]")
    ]
  end

  defp text_summary(%{type: :text, children: children}),
    do: children |> Enum.filter(&is_binary/1) |> Enum.join() |> truncate()

  defp text_summary(_node), do: nil
  defp truncate(value) when byte_size(value) > 80, do: binary_part(value, 0, 77) <> "…"
  defp truncate(value), do: value
  defp flag(attrs, name), do: if(Map.get(attrs, name) == true, do: Atom.to_string(name))
  defp attr(node, name), do: node |> Map.get(:attrs, %{}) |> Map.get(name)
end
