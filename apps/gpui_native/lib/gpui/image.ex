defmodule GPUI.Image do
  @moduledoc """
  Decodes common encoded image formats into renderer-independent `GPUI.Raster` values.

  `decode/1` runs native decoding on a dirty CPU scheduler. File access remains
  explicit through `load/1`, so applications can perform it in their own
  supervised task and report progress or cancellation through normal OTP
  messages.

  Decoding rejects encoded inputs larger than 100 MiB, dimensions above 16,384
  pixels, and decoders requiring more than 256 MiB of allocation. These limits
  keep malformed or adversarial images from exhausting the native runtime.
  """

  alias GPUI.Raster

  @type decode_error :: :invalid_image
  @type load_error :: decode_error() | File.posix()

  @doc "Decodes PNG, JPEG, WebP, GIF, TIFF, BMP, or ICO image bytes."
  @spec decode(binary()) :: {:ok, Raster.t()} | {:error, decode_error()}
  def decode(bytes) when is_binary(bytes) do
    case GPUI.Native.decode_image(bytes) do
      {:ok, width, height, rgba} -> {:ok, Raster.new(width, height, rgba)}
      {:error, "invalid_image"} -> {:error, :invalid_image}
    end
  end

  @doc "Reads and decodes an image file. Call from a supervised task when used by UI code."
  @spec load(Path.t()) :: {:ok, Raster.t()} | {:error, load_error()}
  def load(path) when is_binary(path) do
    with {:ok, bytes} <- File.read(path), do: decode(bytes)
  end
end
