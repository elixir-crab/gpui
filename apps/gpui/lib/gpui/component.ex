defmodule GPUI.Component do
  @moduledoc "Internal component assign and slot normalization used by generated HEEx components."

  alias GPUI.Element

  defmodule Slot do
    @moduledoc "Normalized named-slot value produced by the GPUI template engine."

    @type t :: %__MODULE__{attrs: keyword(), children: [GPUI.Element.child()]}
    defstruct attrs: [], children: []
  end

  @doc "Builds normalized component assigns from attributes, children, and named slots."
  @spec assigns(keyword(), [Element.child()], [{atom(), Slot.t()}]) :: map()
  def assigns(attrs, children, slots \\ [])
      when is_list(attrs) and is_list(children) and is_list(slots) do
    slot_assigns = Enum.group_by(slots, &elem(&1, 0), &elem(&1, 1))

    attrs
    |> Map.new()
    |> Map.merge(slot_assigns)
    |> Map.put(:children, children)
  end
end
