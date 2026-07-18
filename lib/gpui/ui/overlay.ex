defmodule GPUI.UI.Overlay do
  @moduledoc """
  Controlled overlay components backed by GPUI Component.

  Overlay content is declared with ordinary HEEx named slots. Overlay state
  remains authoritative in Elixir assigns while native state preserves focus
  and dismissal behavior between snapshots.
  """

  alias GPUI.Component.Slot
  alias GPUI.Element
  alias GPUI.Schema

  @anchors ~w(top_left top_center top_right bottom_left bottom_center bottom_right left_center right_center)

  @doc """
  Builds a native tooltip with one `:trigger` and one textual `:content` slot.

  `delay` is the show delay in milliseconds from `0` through `60_000`. Set `hoverable` when
  the pointer may move into the tooltip without dismissing it.
  """
  @spec tooltip(map()) :: Element.t()
  def tooltip(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_tooltip)

    trigger = one_slot!(assigns, :trigger, :tooltip)
    content = one_slot!(assigns, :content, :tooltip)
    text = tooltip_text!(content.children)

    unless Map.get(assigns, :children, []) == [] do
      raise ArgumentError, "tooltip content must use :trigger and :content named slots"
    end

    unless is_number(assigns.delay) and assigns.delay >= 0 and assigns.delay <= 60_000 and
             is_boolean(assigns.hoverable) do
      raise ArgumentError,
            "tooltip delay must be between 0 and 60_000 and hoverable must be a boolean"
    end

    id = component_id!(assigns, :ui_tooltip)

    %Element{
      type: :ui_tooltip,
      attrs:
        assigns
        |> Map.drop([:children, :trigger, :content])
        |> Map.put(:id, id)
        |> Map.put(:text, text)
        |> Map.put(:delay, assigns.delay / 1)
        |> Map.to_list(),
      children: [
        %Element{type: :ui_tooltip_trigger, attrs: trigger.attrs, children: trigger.children}
      ]
    }
  end

  @doc """
  Builds a controlled modal dialog with an optional `:trigger` and one `:content` slot.

  Changes to `open` are emitted through `phx-change`. The native dialog traps
  focus while open and restores the previous focus when it closes. Escape and
  overlay clicks request closure when enabled.
  """
  @spec dialog(map()) :: Element.t()
  def dialog(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_dialog)

    trigger = optional_slot!(assigns, :trigger, :dialog)
    content = one_slot!(assigns, :content, :dialog)

    validate_dialog!(assigns)
    id = component_id!(assigns, :ui_dialog)

    children =
      List.wrap(
        trigger &&
          %Element{type: :ui_dialog_trigger, attrs: trigger.attrs, children: trigger.children}
      ) ++
        [%Element{type: :ui_dialog_content, attrs: content.attrs, children: content.children}]

    %Element{
      type: :ui_dialog,
      attrs:
        assigns
        |> Map.drop([:children, :trigger, :content])
        |> Map.put(:id, id)
        |> Map.put(:width, assigns.width / 1)
        |> Map.to_list(),
      children: children
    }
  end

  @doc """
  Builds a controlled dropdown menu with one `:trigger` and one or more `:item` slots.

  `phx-change` receives controlled open-state changes and `phx-select` receives
  the selected item value. Popup-menu keyboard navigation, dismissal, and focus
  restoration are provided by GPUI Component.
  """
  @spec dropdown_menu(map()) :: Element.t()
  def dropdown_menu(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_dropdown_menu)

    trigger = one_slot!(assigns, :trigger, :dropdown_menu)
    items = Map.get(assigns, :item, [])

    validate_dropdown_menu!(assigns, items)
    id = component_id!(assigns, :ui_dropdown_menu)

    children =
      [
        %Element{
          type: :ui_dropdown_menu_trigger,
          attrs: trigger.attrs,
          children: trigger.children
        }
      ] ++
        Enum.map(items, &dropdown_menu_item!/1)

    %Element{
      type: :ui_dropdown_menu,
      attrs:
        assigns
        |> Map.drop([:children, :trigger, :item])
        |> Map.put(:id, id)
        |> Map.to_list(),
      children: children
    }
  end

  @doc """
  Builds a controlled popover with one `:trigger` and one `:content` slot.

  Changes to `open` are emitted through `phx-change`. Escape and, by default,
  outside clicks request closure and restore focus to the trigger.
  """
  @spec popover(map()) :: Element.t()
  def popover(assigns) when is_map(assigns) do
    assigns = Schema.apply_defaults(assigns, :ui_popover)

    trigger = one_slot!(assigns, :trigger, :popover)
    content = one_slot!(assigns, :content, :popover)

    unless Map.get(assigns, :children, []) == [] do
      raise ArgumentError, "popover content must use :trigger and :content named slots"
    end

    unless is_boolean(assigns.open) and is_boolean(assigns.appearance) and
             is_boolean(assigns.closable) do
      raise ArgumentError, "popover open, appearance, and closable must be booleans"
    end

    unless assigns.anchor in @anchors do
      raise ArgumentError,
            "popover anchor must be one of #{Enum.map_join(@anchors, ", ", &inspect/1)}"
    end

    id = component_id!(assigns, :ui_popover)

    %Element{
      type: :ui_popover,
      attrs:
        assigns
        |> Map.drop([:children, :trigger, :content])
        |> Map.put(:id, id)
        |> Map.to_list(),
      children: [
        %Element{type: :ui_popover_trigger, attrs: trigger.attrs, children: trigger.children},
        %Element{type: :ui_popover_content, attrs: content.attrs, children: content.children}
      ]
    }
  end

  defp validate_dropdown_menu!(assigns, items) do
    unless Map.get(assigns, :children, []) == [] do
      raise ArgumentError, "dropdown_menu content must use :trigger and :item named slots"
    end

    unless is_boolean(assigns.open) and is_boolean(assigns.disabled) do
      raise ArgumentError, "dropdown_menu open and disabled must be booleans"
    end

    unless assigns.anchor in @anchors do
      raise ArgumentError,
            "dropdown_menu anchor must be one of #{Enum.map_join(@anchors, ", ", &inspect/1)}"
    end

    if items == [], do: raise(ArgumentError, "dropdown_menu requires at least one :item slot")

    values = Enum.map(items, &dropdown_menu_item_value!/1)

    if Enum.uniq(values) != values do
      raise ArgumentError, "dropdown_menu item values must be unique"
    end
  end

  defp dropdown_menu_item!(%Slot{} = slot) do
    attrs = Map.new(slot.attrs)
    value = dropdown_menu_item_value!(slot)
    disabled = Map.get(attrs, :disabled, false)
    checked = Map.get(attrs, :checked, false)

    unless is_boolean(disabled) and is_boolean(checked) do
      raise ArgumentError, "dropdown_menu item disabled and checked must be booleans"
    end

    label = textual_slot!(slot.children, "dropdown_menu :item")

    %Element{
      type: :ui_dropdown_menu_item,
      attrs:
        attrs
        |> Map.put(:value, value)
        |> Map.put(:label, label)
        |> Map.put(:disabled, disabled)
        |> Map.put(:checked, checked)
        |> Map.to_list(),
      children: []
    }
  end

  defp dropdown_menu_item_value!(%Slot{attrs: attrs}) do
    case Keyword.get(attrs, :value) do
      value when is_binary(value) and value != "" -> value
      _other -> raise ArgumentError, "dropdown_menu :item requires a non-empty string value"
    end
  end

  defp validate_dialog!(assigns) do
    unless Map.get(assigns, :children, []) == [] do
      raise ArgumentError, "dialog content must use :trigger and :content named slots"
    end

    boolean_attrs = Enum.map([:open, :overlay, :closable, :keyboard, :close_button], &assigns[&1])

    unless Enum.all?(boolean_attrs, &is_boolean/1) do
      raise ArgumentError,
            "dialog open, overlay, closable, keyboard, and close_button must be booleans"
    end

    unless is_number(assigns.width) and assigns.width > 0 and assigns.width <= 4096 do
      raise ArgumentError, "dialog width must be greater than 0 and at most 4096"
    end
  end

  defp tooltip_text!(children), do: textual_slot!(children, "tooltip :content")

  defp textual_slot!(children, description) do
    text = Enum.map_join(children, &textual_fragment!(&1, description))

    if text == "", do: raise(ArgumentError, "#{description} must contain text"), else: text
  end

  defp textual_fragment!(%Element{type: :text, children: children}, description),
    do: Enum.map_join(children, &textual_fragment!(&1, description))

  defp textual_fragment!(value, _description) when is_binary(value), do: value

  defp textual_fragment!(value, _description) when is_number(value) or is_atom(value),
    do: to_string(value)

  defp textual_fragment!(value, description),
    do: raise(ArgumentError, "#{description} must be textual, got: #{inspect(value)}")

  defp component_id!(assigns, type) do
    id = Map.get(assigns, :id)

    if is_binary(id) and id != "" do
      id
    else
      raise ArgumentError, "#{type} requires a non-empty string id"
    end
  end

  defp optional_slot!(assigns, name, component) do
    case Map.get(assigns, name, []) do
      [] -> nil
      [%Slot{} = slot] -> slot
      _other -> raise ArgumentError, "#{component} accepts at most one :#{name} slot"
    end
  end

  defp one_slot!(assigns, name, component) do
    case Map.get(assigns, name, []) do
      [%Slot{} = slot] -> slot
      _other -> raise ArgumentError, "#{component} requires exactly one :#{name} slot"
    end
  end
end
