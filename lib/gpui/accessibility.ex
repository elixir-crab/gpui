defmodule GPUI.Accessibility do
  @moduledoc """
  Bounded renderer-independent accessibility contracts for generic elements.

  Semantic native components own their roles and state policy. This module
  validates explicit metadata on generic primitives before it crosses a display
  or transport boundary.
  """

  @role_specs [
    button: :Button,
    checkbox: :CheckBox,
    dialog: :Dialog,
    group: :Group,
    heading: :Heading,
    image: :Image,
    label: :Label,
    link: :Link,
    list: :List,
    list_item: :ListItem,
    progress: :ProgressIndicator,
    radio: :RadioButton,
    slider: :Slider,
    splitter: :Splitter,
    switch: :Switch,
    tab: :Tab,
    tab_list: :TabList,
    tab_panel: :TabPanel,
    text: :TextRun,
    textbox: :TextInput,
    tree: :Tree,
    tree_item: :TreeItem
  ]
  @roles Enum.map(@role_specs, &Atom.to_string(elem(&1, 0)))
  @generic_tags [:div, :span, :scroll, :list, :item]

  @attrs [
    id: :string,
    accessibility_role: {:enum, @roles},
    accessibility_label: :accessibility_label,
    accessibility_description: :accessibility_description,
    accessibility_value: :accessibility_value,
    accessibility_selected: :boolean,
    accessibility_expanded: :boolean,
    accessibility_checked: :accessibility_checked,
    accessibility_orientation: {:enum, ~w(horizontal vertical)}
  ]

  @state_roles [
    accessibility_checked: ~w(checkbox radio switch),
    accessibility_selected: ~w(list_item tab tree_item),
    accessibility_expanded: ~w(button tree_item),
    accessibility_orientation: ~w(slider splitter tab_list tree),
    accessibility_value: ~w(progress slider textbox)
  ]

  @type role :: String.t()
  @type checked :: boolean() | :mixed
  @type state_rule :: {atom(), [String.t()]}

  @doc false
  @spec roles() :: [String.t()]
  def roles, do: @roles

  @doc false
  @spec role_specs() :: [{atom(), atom()}]
  def role_specs, do: @role_specs

  @doc false
  @spec state_roles() :: [state_rule()]
  def state_roles, do: @state_roles

  @doc false
  @spec attrs() :: keyword(GPUI.Schema.Component.attr_type())
  def attrs, do: @attrs

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

  defp validate_state_roles!(_tag, attrs) do
    role = Map.get(attrs, :accessibility_role)

    Enum.each(@state_roles, fn {attribute, allowed} ->
      validate_state_role!(attrs, attribute, role, allowed)
    end)
  end

  defp validate_state_role!(attrs, attribute, role, allowed) do
    if Map.has_key?(attrs, attribute) and role not in allowed do
      raise ArgumentError,
            "#{attribute} is not supported for accessibility role #{inspect(role)}"
    end
  end
end
