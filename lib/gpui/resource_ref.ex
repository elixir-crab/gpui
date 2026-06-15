defmodule GPUI.ResourceRef do
  @moduledoc """
  Reference to a remote/display resource such as a raster image.
  """

  @type t :: %__MODULE__{id: term(), type: atom()}
  defstruct [:id, :type]

  @spec new(term(), atom()) :: t()
  def new(id, type), do: %__MODULE__{id: id, type: type}

  @doc false
  def to_payload(%__MODULE__{} = ref), do: %{__type__: :resource_ref, id: ref.id, type: ref.type}
end

defimpl Inspect, for: GPUI.ResourceRef do
  import Inspect.Algebra

  def inspect(ref, opts) do
    concat(["#GPUI.ResourceRef<", to_doc(ref.type, opts), " ", to_doc(ref.id, opts), ">"])
  end
end
