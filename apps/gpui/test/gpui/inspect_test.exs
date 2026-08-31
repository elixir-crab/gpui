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

  test "bounds inspection for snapshots, updates, text, and transfers" do
    snapshot = %GPUI.Snapshot{windows: [%{}], resources: %{"image" => %{}}}
    update = %GPUI.Runtime.Update{revision: 4, events: [%{type: :click}], snapshot: snapshot}

    text = %GPUI.Text.Snapshot{
      revision: 3,
      text: String.duplicate("x", 500),
      selections: [],
      can_undo: true,
      can_redo: false
    }

    payload =
      GPUI.Transfer.Payload.new(
        text: String.duplicate("secret", 20),
        external_paths: ["/private/file"]
      )

    assert inspect(snapshot) == "#GPUI.Snapshot<windows=1 resources=1>"
    assert inspect(update) == "#GPUI.Runtime.Update<revision=4 events=1 windows=1>"

    assert inspect(text) ==
             "#GPUI.Text.Snapshot<revision=3 bytes=500 selections=0 undo=true redo=false>"

    assert inspect(payload) == "#GPUI.Transfer.Payload<text_bytes=120 external_paths=1>"
  end

  test "inspects transport wrappers without dumping sockets" do
    listener = %GPUI.Remote.Transport.TCP.Listener{socket: :hidden, mode: :tcp}
    conn = %GPUI.Remote.Transport.TCP.Connection{socket: :hidden, mode: :ssl}

    assert inspect(listener) == "#GPUI.Remote.Transport.TCP.Listener<tcp>"
    assert inspect(conn) == "#GPUI.Remote.Transport.TCP.Connection<ssl>"
  end
end
