GPUITest.Examples.load!(:resource_ref_image)

defmodule GPUI.ResourceRefImageExampleTest do
  use GPUI.Test, async: true

  test "installs one reusable raster while snapshots retain only its reference" do
    raster = Examples.ResourceRefImage.raster()
    assert %GPUI.Raster{width: 160, height: 160} = raster

    runtime = start_gpui!(Examples.ResourceRefImage.App)
    :ok = GPUI.Runtime.put_resource(runtime, "preview", GPUI.Raster.to_payload(raster))

    assert %{
             attrs: %{
               label: "Four-color raster preview",
               raster: %{__type__: :resource_ref, id: "preview", type: :raster}
             }
           } = runtime |> tree() |> find!(type: :img)

    assert %{"preview" => %{__type__: :raster, width: 160, height: 160}} =
             snapshot(runtime).resources
  end
end
