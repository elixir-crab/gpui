defmodule GPUI.Raster do
  @moduledoc """
  Generic packed 32-bit CPU raster image payload for GPUI image elements.

  This is renderer-independent: image decoders, screenshots, video frames, or
  tensors can produce `%GPUI.Raster{}` values. Rows may be tightly packed or
  use an explicit byte stride.
  """

  @type format :: :rgba8 | :bgra8

  @enforce_keys [:width, :height, :data]
  defstruct [:width, :height, :data, format: :rgba8, stride: nil]

  @type t :: %__MODULE__{
          width: pos_integer(),
          height: pos_integer(),
          format: format(),
          data: binary(),
          stride: pos_integer() | nil
        }

  @spec new(pos_integer(), pos_integer(), binary(), keyword()) :: t()
  def new(width, height, data, opts \\ [])
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 and
             is_binary(data) do
    %__MODULE__{
      width: width,
      height: height,
      data: data,
      format: Keyword.get(opts, :format, :rgba8),
      stride: Keyword.get(opts, :stride)
    }
    |> validate!()
  end

  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = raster) do
    unless raster.format in [:rgba8, :bgra8] do
      raise ArgumentError, "unsupported raster format #{inspect(raster.format)}"
    end

    row_bytes = raster.width * 4
    stride = raster.stride || row_bytes

    cond do
      not is_integer(stride) or stride < row_bytes ->
        raise ArgumentError, "raster stride must be at least #{row_bytes} bytes"

      byte_size(raster.data) < stride * (raster.height - 1) + row_bytes ->
        raise ArgumentError, "raster data is too short for dimensions and stride"

      true ->
        raster
    end
  end

  @doc false
  @spec to_payload(t()) :: map()
  def to_payload(%__MODULE__{} = raster) do
    raster = validate!(raster)

    %{
      __type__: :raster,
      width: raster.width,
      height: raster.height,
      format: raster.format,
      data: raster.data,
      stride: raster.stride
    }
  end
end
