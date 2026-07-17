defmodule GPUI.RasterTest do
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
             stride: nil
           } = GPUI.Raster.to_payload(raster)
  end

  test "validates raster payload shape" do
    assert_raise ArgumentError, ~r/data is too short/, fn ->
      GPUI.Raster.new(2, 1, <<255, 0, 0, 255>>)
    end

    assert_raise ArgumentError, ~r/unsupported raster format/, fn ->
      GPUI.Raster.new(1, 1, <<255, 0, 0, 255>>, format: :gray8)
    end

    assert %GPUI.Raster{stride: 8} =
             GPUI.Raster.new(1, 2, <<255, 0, 0, 255, 0, 0, 0, 0, 0, 255, 0, 255>>, stride: 8)
  end

  test "supports <img raster={raster}> in GPUI templates" do
    raster = GPUI.Raster.new(1, 1, <<255, 0, 0, 255>>)

    assert %GPUI.Element{
             type: :img,
             attrs: [raster: ^raster, label: "Preview"],
             children: []
           } =
             ~GPUI"""
             <img raster={raster} label="Preview" />
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
