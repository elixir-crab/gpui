defmodule GPUI.UI.Collection.Selection do
  @moduledoc """
  Controlled collection identity and optional logical index.

  Use an index when the selected or revealed item may be outside the currently
  loaded source slice. `assigns/2` converts the value to component options for
  either controlled selection or reveal behavior.
  """

  @enforce_keys [:id]
  defstruct [:id, :index]

  @type t :: %__MODULE__{id: String.t() | nil, index: non_neg_integer() | nil}

  @doc "Builds a controlled collection identity with an optional logical index."
  @spec new(String.t() | nil, non_neg_integer() | nil) :: t()
  def new(id, index \\ nil)

  def new(id, index)
      when (is_nil(id) or (is_binary(id) and id != "")) and
             (is_nil(index) or (is_integer(index) and index >= 0)) do
    %__MODULE__{id: id, index: index}
  end

  @doc "Returns `:selected` assigns for the controlled identity."
  @spec assigns(t(), :selected | :reveal) :: map()
  def assigns(%__MODULE__{} = selection, :selected) do
    optional_index(%{selected: selection.id}, :selected_index, selection.index)
  end

  def assigns(%__MODULE__{} = selection, :reveal) do
    optional_index(%{reveal: selection.id}, :reveal_index, selection.index)
  end

  defp optional_index(assigns, _name, nil), do: assigns
  defp optional_index(assigns, name, index), do: Map.put(assigns, name, index)
end
