defmodule GPUI do
  @moduledoc """
  Elixir-facing DSL for GPUI applications and views.

  The public API builds ordinary Elixir data. Sessions render serializable
  snapshots, and displays present those snapshots locally or remotely.
  """

  alias GPUI.Element

  @doc "Creates a `div` element."
  defmacro div do
    quote do
      %Element{type: :div, attrs: [], children: []}
    end
  end

  defmacro div(attrs) do
    case Keyword.pop(attrs, :do) do
      {nil, attrs} ->
        quote do
          %Element{type: :div, attrs: unquote(attrs), children: []}
        end

      {block, attrs} ->
        children = block_children(block)

        quote do
          %Element{type: :div, attrs: unquote(attrs), children: List.flatten(unquote(children))}
        end
    end
  end

  defmacro div(attrs, do: block) do
    children = block_children(block)

    quote do
      %Element{type: :div, attrs: unquote(attrs), children: List.flatten(unquote(children))}
    end
  end

  @doc "Creates a text node."
  defmacro text(value) do
    quote do
      %Element{type: :text, attrs: [], children: [unquote(value)]}
    end
  end

  @doc "Adds a child to an element for pipe-style view construction."
  @spec child(Element.t(), Element.child()) :: Element.t()
  def child(%Element{} = element, child) do
    Element.append_child(element, child)
  end

  @doc "Adds flex display style to an element."
  @spec flex(Element.t()) :: Element.t()
  def flex(%Element{} = element), do: Element.put_style(element, :display, :flex)

  @doc "Adds column flex direction to an element."
  @spec flex_col(Element.t()) :: Element.t()
  def flex_col(%Element{} = element), do: Element.put_style(element, :flex_direction, :column)

  @doc "Centers children on the cross axis."
  @spec items_center(Element.t()) :: Element.t()
  def items_center(%Element{} = element), do: Element.put_style(element, :align_items, :center)

  @doc "Centers children on the main axis."
  @spec justify_center(Element.t()) :: Element.t()
  def justify_center(%Element{} = element),
    do: Element.put_style(element, :justify_content, :center)

  @doc "Sets background color."
  @spec bg(Element.t(), term()) :: Element.t()
  def bg(%Element{} = element, color), do: Element.put_style(element, :background, color)

  @doc "Sets width and height to the same value."
  @spec size(Element.t(), term()) :: Element.t()
  def size(%Element{} = element, size) do
    element
    |> Element.put_style(:width, size)
    |> Element.put_style(:height, size)
  end

  @doc "Represents a GPUI pixel length."
  @spec px(number()) :: {:px, float()}
  def px(value) when is_integer(value) or is_float(value), do: {:px, value * 1.0}

  @doc "Represents a GPUI RGB color."
  @spec rgb(non_neg_integer()) :: {:rgb, non_neg_integer()}
  def rgb(value) when is_integer(value) and value >= 0, do: {:rgb, value}

  defp block_children({:__block__, _meta, expressions}), do: expressions
  defp block_children(expression), do: [expression]
end
