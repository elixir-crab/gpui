defmodule GPUI.ResourceRefTest do
  use ExUnit.Case, async: true

  import GPUI.Template, only: [sigil_GPUI: 2]

  test "serializes resource refs in element attrs" do
    ref = GPUI.ResourceRef.new("logo", :raster)

    payload =
      ~GPUI"""
      <img raster={ref} />
      """
      |> GPUI.Element.to_payload()

    assert get_in(payload, [:attrs, :raster]) == %{
             __type__: :resource_ref,
             id: "logo",
             type: :raster
           }
  end

  test "inspects resource refs concisely" do
    assert inspect(GPUI.ResourceRef.new("logo", :raster)) == "#GPUI.ResourceRef<:raster \"logo\">"
  end
end
