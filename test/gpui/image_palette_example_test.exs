Code.require_file("../../examples/image_palette/support/image_palette.exs", __DIR__)

defmodule GPUI.ImagePaletteExampleTest do
  use GPUI.Test, async: false

  alias Examples.ImagePalette.Analysis
  alias Examples.ImagePalette.App
  alias Examples.ImagePalette.Coordinator

  test "extracts a deterministic palette and bounded preview" do
    result = Analysis.analyze(source_raster(), colors: 3)

    assert %{width: 4, height: 2, preview: %GPUI.Raster{width: 4, height: 2}} = result

    assert Enum.map(result.palette, & &1.hex) == ["#FF0000", "#0000FF", "#00FF00"]
    assert Enum.map(result.palette, & &1.count) == [4, 2, 2]

    assert Analysis.css(result.palette) ==
             ":root {\n  --palette-1: #FF0000;\n  --palette-2: #0000FF;\n  --palette-3: #00FF00;\n}\n"
  end

  test "loads, analyzes, installs, selects, and exports through supervised work" do
    runtime = start_gpui!(App, args: %{path: "/fixtures/colors.bmp"})
    task_supervisor = start_task_supervisor!()
    owner = self()

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator,
         runtime: runtime,
         task_supervisor: task_supervisor,
         read: fn "/fixtures/colors.bmp" -> {:ok, "encoded"} end,
         decode: fn "encoded" -> {:ok, source_raster()} end,
         write: fn path, css ->
           send(owner, {:css_written, path, css})
           :ok
         end,
         owner: owner},
        id: make_ref()
      )
    )

    click(runtime, "load_image")
    assert_receive {:image_palette, :loaded, 1}

    assert %{
             status: :ready,
             progress: 100,
             image: %GPUI.ResourceRef{id: "image-palette-preview"},
             palette: [%{hex: "#FF0000"} | _colors],
             selected: "#FF0000"
           } = assigns(runtime)

    assert %{"image-palette-preview" => %{__type__: :raster}} = snapshot(runtime).resources

    click(runtime, "select_color:#0000FF")
    assert %{selected: "#0000FF"} = assigns(runtime)

    change(runtime, "export_path_changed", "/tmp/palette.css")
    click(runtime, "export_palette")

    assert_receive {:css_written, "/tmp/palette.css", css}
    assert css =~ "--palette-1: #FF0000"
    assert_receive {:image_palette, :exported, "/tmp/palette.css"}
    assert %{status: :exported, stage: "Saved /tmp/palette.css"} = assigns(runtime)
  end

  test "reports file errors without requiring native image decoding" do
    runtime = start_gpui!(App, args: %{path: "/missing/image.png"})
    task_supervisor = start_task_supervisor!()

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator,
         runtime: runtime,
         task_supervisor: task_supervisor,
         read: fn _path -> {:error, :enoent} end,
         owner: self()},
        id: make_ref()
      )
    )

    click(runtime, "load_image")
    assert_receive {:image_palette, :failed, 1, message}
    assert message =~ "no such file or directory"
    assert %{status: :error, error: ^message} = assigns(runtime)
  end

  defp start_task_supervisor! do
    start_supervised!(Supervisor.child_spec({Task.Supervisor, []}, id: make_ref()))
  end

  defp source_raster do
    red = <<255, 0, 0, 255>>
    blue = <<0, 0, 255, 255>>
    green = <<0, 255, 0, 255>>
    GPUI.Raster.new(4, 2, red <> red <> blue <> green <> red <> red <> blue <> green)
  end
end
