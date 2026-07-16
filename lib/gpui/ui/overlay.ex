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

    trigger = one_slot!(assigns, :trigger)
    content = one_slot!(assigns, :content)

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

    id = Map.get(assigns, :id)

    unless is_binary(id) and id != "" do
      raise ArgumentError, "ui_popover requires a non-empty string id"
    end

    %Element{
      type: :ui_popover,
      attrs:
        assigns
        |> Map.drop([:children, :trigger, :content])
        |> Map.to_list(),
      children: [
        %Element{type: :ui_popover_trigger, attrs: trigger.attrs, children: trigger.children},
        %Element{type: :ui_popover_content, attrs: content.attrs, children: content.children}
      ]
    }
  end

  defp one_slot!(assigns, name) do
    case Map.get(assigns, name, []) do
      [%Slot{} = slot] -> slot
      _other -> raise ArgumentError, "popover requires exactly one :#{name} slot"
    end
  end
end
