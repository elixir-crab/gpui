GPUITest.Examples.load!(:image_lab)

defmodule GPUI.Native.ImageLabE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

  alias Examples.ImageLab.App
  alias Examples.ImageLab.Coordinator

  @moduletag :e2e

  test "decodes, analyzes, installs, and exports an image through native GPUI", %{
    desktop: desktop
  } do
    fixture =
      Path.join(System.tmp_dir!(), "gpui-image-palette-#{System.unique_integer([:positive])}.bmp")

    export = Path.rootname(fixture) <> ".css"
    File.write!(fixture, bmp_fixture())

    on_exit(fn ->
      File.rm(fixture)
      File.rm(export)
    end)

    runtime = start_runtime!(desktop, app: App, args: %{path: fixture, export_path: export})

    task_supervisor = start_supervised!({Task.Supervisor, []})

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator, runtime: runtime, task_supervisor: task_supervisor, owner: self()},
        id: make_ref()
      )
    )

    native_window_id = Desktop.window!(desktop, "Image Lab")
    Desktop.await_frame!(desktop, runtime, 1, native_window_id)

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: 1,
      event: "load_image"
    })

    assert_receive {:image_lab, :loaded, 1}, 5_000
    Desktop.await_frame!(desktop, runtime, 1, native_window_id)

    assert %{
             status: :ready,
             image_width: 2,
             image_height: 1,
             image: %GPUI.ResourceRef{id: "image-palette-preview"}
           } = GPUI.Runtime.snapshot(runtime).windows |> hd() |> get_in([:root, :assigns])

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: 1,
      event: "export_palette"
    })

    assert_receive {:image_lab, :exported, ^export}
    assert File.read!(export) =~ "--palette-1: #"
    assert Process.alive?(runtime)
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
