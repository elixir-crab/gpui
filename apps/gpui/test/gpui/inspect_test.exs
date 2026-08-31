defmodule GPUI.InspectTest do
  use ExUnit.Case, async: true

  test "inspects elements concisely" do
    element = %GPUI.Element{
      type: :div,
      attrs: [class: "flex", id: "root"],
      children: ["hello", "world"]
    }

    assert inspect(element) == "#GPUI.Element<:div#root attrs=2 children=2>"
  end

  test "inspects rasters without dumping binary data" do
    raster = GPUI.Raster.new(1, 2, <<255, 0, 0, 255, 0, 255, 0, 255>>)

    assert inspect(raster) == "#GPUI.Raster<1x2 rgba8 bytes=8>"
  end

  test "inspects strided rasters" do
    raster = GPUI.Raster.new(1, 2, <<255, 0, 0, 255, 0, 0, 0, 0, 0, 255, 0, 255>>, stride: 8)

    assert inspect(raster) == "#GPUI.Raster<1x2 rgba8 bytes=12 stride=8>"
  end

  test "inspects window specs by root module instead of assigns" do
    window = %GPUI.WindowSpec{
      id: 1,
      title: "Counter",
      size: {320, 240},
      root: {__MODULE__, %{count: 42}}
    }

    assert inspect(window) ==
             "#GPUI.WindowSpec<id=1 key=nil title=\"Counter\" size={320, 240} root=GPUI.InspectTest>"
  end

  test "inspects transport wrappers without dumping sockets" do
    listener = %GPUI.Remote.Transport.TCP.Listener{socket: :hidden, mode: :tcp}
    conn = %GPUI.Remote.Transport.TCP.Connection{socket: :hidden, mode: :ssl}

    assert inspect(listener) == "#GPUI.Remote.Transport.TCP.Listener<tcp>"
    assert inspect(conn) == "#GPUI.Remote.Transport.TCP.Connection<ssl>"
  end
end
