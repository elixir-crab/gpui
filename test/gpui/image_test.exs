defmodule GPUI.ImageTest do
  use ExUnit.Case, async: true

  @moduletag :native

  test "decodes encoded images into RGBA rasters" do
    assert {:ok,
            %GPUI.Raster{
              width: 2,
              height: 1,
              format: :rgba8,
              data: <<255, 0, 0, 255, 0, 255, 0, 255>>
            }} = GPUI.Image.decode(bmp_fixture())
  end

  test "rejects malformed encoded images" do
    assert {:error, :invalid_image} = GPUI.Image.decode("not an image")
  end

  defp bmp_fixture do
    <<
      "BM",
      62::little-32,
      0::little-16,
      0::little-16,
      54::little-32,
      40::little-32,
      2::little-signed-32,
      1::little-signed-32,
      1::little-16,
      24::little-16,
      0::little-32,
      8::little-32,
      2_835::little-signed-32,
      2_835::little-signed-32,
      0::little-32,
      0::little-32,
      0,
      0,
      255,
      0,
      255,
      0,
      0,
      0
    >>
  end
end
