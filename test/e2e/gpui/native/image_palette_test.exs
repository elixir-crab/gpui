Code.require_file("../../../../examples/image_palette/support/image_palette.exs", __DIR__)

defmodule GPUI.Native.ImagePaletteE2ETest do
  use ExUnit.Case, async: false

  alias Examples.ImagePalette.App
  alias Examples.ImagePalette.Coordinator
  alias GPUITest.E2E.Desktop

  @moduletag :e2e

  test "decodes, analyzes, installs, and exports an image through native GPUI" do
    fixture =
      Path.join(System.tmp_dir!(), "gpui-image-palette-#{System.unique_integer([:positive])}.bmp")

    export = Path.rootname(fixture) <> ".css"
    File.write!(fixture, bmp_fixture())

    on_exit(fn ->
      File.rm(fixture)
      File.rm(export)
    end)

    {:ok, runtime} =
      GPUI.Runtime.start_link(app: App, args: %{path: fixture, export_path: export})

    on_exit(fn -> Desktop.stop_process(runtime) end)

    task_supervisor = start_supervised!({Task.Supervisor, []})

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator, runtime: runtime, task_supervisor: task_supervisor, owner: self()},
        id: make_ref()
      )
    )

    native_window_id = Desktop.window_id!("Image Palette")
    Desktop.await_frame!(runtime, 1, native_window_id)

    {_event, _snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{type: :click, window_id: 1, event: "load_image"})

    assert_receive {:image_palette, :loaded, 1}
    Desktop.await_frame!(runtime, 1, native_window_id)

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

    assert_receive {:image_palette, :exported, ^export}
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
