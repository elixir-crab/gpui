defmodule GPUI.Accessibility do
  @moduledoc """
  Bounded renderer-independent accessibility contracts for generic elements.

  Semantic native components own their roles and state policy. This module
  validates explicit metadata on generic primitives before it crosses a display
  or transport boundary.
  """

  @roles ~w(button dialog group heading image label link list list_item progress radio slider splitter tab tab_list tab_panel text textbox tree tree_item)
  @generic_tags [:div, :span, :scroll, :list, :item]

  @type role :: String.t()

  @doc false
  @spec roles() :: [String.t()]
  def roles, do: @roles

  @doc false
  @spec attrs() :: keyword(GPUI.Schema.Component.attr_type())
  def attrs do
    GPUI.Schema.component!(:div).attrs
  end

  @doc false
  @spec metadata?(map()) :: boolean()
  def metadata?(attrs) when is_map(attrs) do
    Map.has_key?(attrs, :accessibility_role) or
      Map.has_key?(attrs, :accessibility_label) or
      Map.has_key?(attrs, :accessibility_description)
  end

  @doc false
  @spec validate_generic!(atom(), map()) :: map()
  def validate_generic!(tag, attrs) when tag in @generic_tags and is_map(attrs) do
    if metadata?(attrs) do
      validate_identity!(tag, attrs)
      validate_role!(tag, attrs)
    end

    attrs
  end

  def validate_generic!(tag, attrs) when is_atom(tag) and is_map(attrs), do: attrs

  defp validate_identity!(tag, attrs) do
    id = Map.get(attrs, :id)

    unless is_binary(id) and id != "" do
      raise ArgumentError,
            "#{tag} with accessibility metadata requires a non-empty string id"
    end
  end

  defp validate_role!(tag, attrs) do
    role? = Map.has_key?(attrs, :accessibility_role)
    named? = Map.has_key?(attrs, :accessibility_label)
    described? = Map.has_key?(attrs, :accessibility_description)

    if (named? or described?) and not role? do
      raise ArgumentError,
            "#{tag} accessibility label or description requires :accessibility_role"
    end
  end
end
