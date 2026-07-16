defmodule GPUI.UI.Overlay do
  @moduledoc """
  Controlled overlay components backed by GPUI Component.

  Overlay content is declared with ordinary HEEx named slots. Overlay state
  remains authoritative in Elixir assigns while native state preserves focus
  and dismissal behavior between snapshots.
  """

  alias GPUI.Component.Slot
  alias GPUI.Element

  @anchors ~w(top_left top_center top_right bottom_left bottom_center bottom_right left_center right_center)

  @doc """
  Builds a native tooltip with one `:trigger` and one textual `:content` slot.

  `delay` is the show delay in milliseconds from `0` through `60_000`. Set `hoverable` when
  the pointer may move into the tooltip without dismissing it.
  """
  @spec tooltip(map()) :: Element.t()
  def tooltip(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> Map.put_new(:delay, 500.0)
      |> Map.put_new(:hoverable, false)

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
  Builds a controlled popover with one `:trigger` and one `:content` slot.

  Changes to `open` are emitted through `phx-change`. Escape and, by default,
  outside clicks request closure and restore focus to the trigger.
  """
  @spec popover(map()) :: Element.t()
  def popover(assigns) when is_map(assigns) do
    assigns =
      assigns
      |> Map.put_new(:open, false)
      |> Map.put_new(:anchor, "top_left")
      |> Map.put_new(:appearance, true)
      |> Map.put_new(:closable, true)

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

  defp tooltip_text!(children) do
    text = Enum.map_join(children, &tooltip_fragment!/1)

    if text == "", do: raise(ArgumentError, "tooltip :content must contain text"), else: text
  end

  defp tooltip_fragment!(%Element{type: :text, children: children}),
    do: Enum.map_join(children, &tooltip_fragment!/1)

  defp tooltip_fragment!(value) when is_binary(value), do: value
  defp tooltip_fragment!(value) when is_number(value) or is_atom(value), do: to_string(value)

  defp tooltip_fragment!(value),
    do: raise(ArgumentError, "tooltip :content must be textual, got: #{inspect(value)}")

  defp component_id!(assigns, type) do
    id = Map.get(assigns, :id)

    if is_binary(id) and id != "" do
      id
    else
      raise ArgumentError, "#{type} requires a non-empty string id"
    end
  end

  defp one_slot!(assigns, name, component) do
    case Map.get(assigns, name, []) do
      [%Slot{} = slot] -> slot
      _other -> raise ArgumentError, "#{component} requires exactly one :#{name} slot"
    end
  end
end
