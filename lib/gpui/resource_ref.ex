defmodule GPUI.ResourceRef do
  @moduledoc """
  Reference to a remote/display resource such as a raster image.
  """

  @enforce_keys [:id, :type]
  defstruct [:id, :type]

  @type t :: %__MODULE__{id: String.t(), type: :raster}

  @spec new(String.Chars.t(), :raster) :: t()
  def new(id, :raster), do: %__MODULE__{id: to_string(id), type: :raster}

  @doc false
  def to_payload(%__MODULE__{} = ref), do: %{__type__: :resource_ref, id: ref.id, type: ref.type}
end

defimpl Inspect, for: GPUI.ResourceRef do
  import Inspect.Algebra

  def inspect(ref, opts) do
    concat(["#GPUI.ResourceRef<", to_doc(ref.type, opts), " ", to_doc(ref.id, opts), ">"])
  end
end
