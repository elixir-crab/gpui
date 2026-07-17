defmodule Examples.ImagePalette.Analysis do
  @moduledoc false

  import Bitwise

  alias GPUI.Raster

  @default_colors 8
  @max_samples 80_000
  @preview_width 520
  @preview_height 420

  @spec analyze(Raster.t(), keyword()) :: %{
          width: pos_integer(),
          height: pos_integer(),
          preview: Raster.t(),
          palette: [map()]
        }
  def analyze(%Raster{} = raster, opts \\ []) do
    progress = Keyword.get(opts, :progress, fn _percent, _stage -> :ok end)
    color_count = Keyword.get(opts, :colors, @default_colors)

    progress.(45, "Sampling pixels")
    palette = dominant_colors(raster, color_count)
    progress.(75, "Building preview")
    preview = preview(raster)
    progress.(90, "Preparing palette")

    %{
      width: raster.width,
      height: raster.height,
      preview: preview,
      palette: palette
    }
  end

  @spec css([map()]) :: String.t()
  def css(palette) when is_list(palette) do
    declarations =
      palette
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {color, index} ->
        "  --palette-#{index}: #{color.hex};"
      end)

    ":root {\n#{declarations}\n}\n"
  end

  defp dominant_colors(raster, color_count) do
    step = sample_step(raster.width * raster.height)

    bins =
      for y <- stepped_range(raster.height, step),
          x <- stepped_range(raster.width, step),
          reduce: %{} do
        bins -> add_pixel(bins, pixel(raster, x, y))
      end

    bins
    |> Enum.map(fn {_bin, {count, red, green, blue}} ->
      red = div(red, count)
      green = div(green, count)
      blue = div(blue, count)

      %{
        red: red,
        green: green,
        blue: blue,
        count: count,
        hex: hex(red, green, blue)
      }
    end)
    |> Enum.sort_by(fn color -> {-color.count, color.red, color.green, color.blue} end)
    |> Enum.take(color_count)
  end

  defp add_pixel(bins, {_red, _green, _blue, alpha}) when alpha < 16, do: bins

  defp add_pixel(bins, {red, green, blue, _alpha}) do
    bin = {red >>> 4, green >>> 4, blue >>> 4}

    Map.update(bins, bin, {1, red, green, blue}, fn {count, red_sum, green_sum, blue_sum} ->
      {count + 1, red_sum + red, green_sum + green, blue_sum + blue}
    end)
  end

  defp preview(raster) do
    {width, height} = preview_size(raster.width, raster.height)

    data =
      for y <- 0..(height - 1), x <- 0..(width - 1), into: <<>> do
        source_x = div(x * raster.width, width)
        source_y = div(y * raster.height, height)
        {red, green, blue, alpha} = pixel(raster, source_x, source_y)
        <<red, green, blue, alpha>>
      end

    Raster.new(width, height, data)
  end

  defp preview_size(width, height) do
    scale = min(1.0, min(@preview_width / width, @preview_height / height))
    {max(1, floor(width * scale)), max(1, floor(height * scale))}
  end

  defp pixel(%Raster{} = raster, x, y) do
    stride = raster.stride || raster.width * 4
    offset = y * stride + x * 4
    <<_prefix::binary-size(^offset), first, green, third, alpha, _rest::binary>> = raster.data

    case raster.format do
      :rgba8 -> {first, green, third, alpha}
      :bgra8 -> {third, green, first, alpha}
    end
  end

  defp sample_step(pixel_count) when pixel_count <= @max_samples, do: 1

  defp sample_step(pixel_count),
    do: pixel_count |> Kernel./(@max_samples) |> :math.sqrt() |> ceil()

  defp stepped_range(length, step), do: 0..(length - 1)//step

  defp hex(red, green, blue) do
    "#" <> hex_byte(red) <> hex_byte(green) <> hex_byte(blue)
  end

  defp hex_byte(value),
    do: value |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(2, "0")
end
