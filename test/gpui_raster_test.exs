defmodule GPUIRasterTest do
  use ExUnit.Case, async: true

  import GPUI.Template, only: [sigil_GPUI: 2]

  test "constructs generic raster payloads" do
    raster = GPUI.Raster.new(1, 1, <<255, 0, 0, 255>>)

    assert %{
             __type__: :raster,
             width: 1,
             height: 1,
             format: :rgba8,
             data: <<255, 0, 0, 255>>,
             stride: nil,
             color_space: :srgb,
             alpha: :premultiplied
           } = GPUI.Raster.to_payload(raster)
  end

  test "supports <img raster={raster}> in GPUI templates" do
    raster = GPUI.Raster.new(1, 1, <<255, 0, 0, 255>>)

    assert %GPUI.Element{type: :img, attrs: [raster: ^raster], children: []} =
             ~GPUI"""
             <img raster={raster} />
             """
  end

  test "serializes raster attrs for native payloads" do
    raster = GPUI.Raster.new(1, 1, <<255, 0, 0, 255>>)

    payload =
      ~GPUI"""
      <img raster={raster} />
      """
      |> GPUI.Element.to_payload()

    assert %{
             type: :img,
             attrs: %{
               raster: %{
                 __type__: :raster,
                 width: 1,
                 height: 1,
                 format: :rgba8,
                 data: <<255, 0, 0, 255>>
               }
             },
             children: []
           } = payload
  end
end
