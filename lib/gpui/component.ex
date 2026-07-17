defmodule GPUI.Component do
  @moduledoc false

  alias GPUI.Element

  defmodule Slot do
    @moduledoc false

    @type t :: %__MODULE__{attrs: keyword(), children: [Element.child()]}
    defstruct attrs: [], children: []
  end

  @doc false
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
