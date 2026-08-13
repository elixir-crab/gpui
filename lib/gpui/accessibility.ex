defmodule GPUI.Accessibility do
  @moduledoc """
  Bounded renderer-independent accessibility contracts for generic elements.

  Semantic native components own their roles and state policy. This module
  validates explicit metadata on generic primitives before it crosses a display
  or transport boundary.
  """

  @roles ~w(button checkbox dialog group heading image label link list list_item progress radio slider splitter switch tab tab_list tab_panel text textbox tree tree_item)
  @generic_tags [:div, :span, :scroll, :list, :item]

  @type role :: String.t()
  @type checked :: boolean() | :mixed

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
    Enum.any?(
      [
        :accessibility_role,
        :accessibility_label,
        :accessibility_description,
        :accessibility_value,
        :accessibility_selected,
        :accessibility_expanded,
        :accessibility_checked,
        :accessibility_orientation
      ],
      &Map.has_key?(attrs, &1)
    )
  end

  @doc false
  @spec validate_generic!(atom(), map()) :: map()
  def validate_generic!(tag, attrs) when tag in @generic_tags and is_map(attrs) do
    if metadata?(attrs) do
      validate_identity!(tag, attrs)
      validate_role!(tag, attrs)
      validate_state_roles!(tag, attrs)
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

  defp validate_state_roles!(tag, attrs) do
    role = Map.get(attrs, :accessibility_role)

    validate_state_role!(tag, attrs, :accessibility_checked, role, ~w(checkbox radio switch))
    validate_state_role!(tag, attrs, :accessibility_selected, role, ~w(list_item tab tree_item))
    validate_state_role!(tag, attrs, :accessibility_expanded, role, ~w(button tree_item))

    validate_state_role!(
      tag,
      attrs,
      :accessibility_orientation,
      role,
      ~w(slider splitter tab_list tree)
    )

    validate_state_role!(tag, attrs, :accessibility_value, role, ~w(progress slider textbox))
  end

  defp validate_state_role!(_tag, attrs, attribute, role, allowed) do
    if Map.has_key?(attrs, attribute) and role not in allowed do
      raise ArgumentError,
            "#{attribute} is not supported for accessibility role #{inspect(role)}"
    end
  end
end
