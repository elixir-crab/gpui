GPUITest.Examples.load!(:image_palette)

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
    runtime = start_runtime!(App)
    task_supervisor = start_task_supervisor!()
    owner = self()

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator,
         runtime: runtime,
         task_supervisor: task_supervisor,
         decode: fn "encoded" -> {:ok, source_raster()} end,
         write: fn path, css ->
           send(owner, {:css_written, path, css})
           :ok
         end,
         owner: owner},
        id: make_ref()
      )
    )

    file_select(runtime, "image_file_selected", "colors.bmp", "encoded")
    assert_receive {:image_palette, :loaded, 1}

    assert %{
             status: :ready,
             progress: 100,
             source_name: "colors.bmp",
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

    click(runtime, "palette_copied")
    assert %{status: :copied, stage: "CSS copied to clipboard"} = assigns(runtime)

    click(runtime, "export_palette")
    assert_receive {:css_written, "/tmp/palette.css", _css}
    assert_receive {:image_palette, :exported, "/tmp/palette.css"}
  end

  test "disables retained palette actions while a replacement is loading" do
    result = Analysis.analyze(source_raster(), colors: 3)

    runtime =
      start_runtime!(App,
        args: %{path: "/fixtures/colors.bmp", export_path: "palette.css", result: result}
      )

    click(runtime, "load_image")
    assert %{status: :loading} = assigns(runtime)
    assert %{attrs: %{disabled: true}} = runtime |> tree() |> find!(id: "export-palette")
    assert %{attrs: %{disabled: true}} = runtime |> tree() |> find!(id: "copy-palette-css")
    assert %{attrs: %{disabled: true}} = runtime |> tree() |> find!(id: "color-#FF0000")
  end

  test "cancels active analysis and ignores its stale messages" do
    runtime = start_runtime!(App)
    task_supervisor = start_task_supervisor!()
    owner = self()

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator,
         runtime: runtime,
         task_supervisor: task_supervisor,
         decode: fn "encoded" -> {:ok, source_raster()} end,
         analyze: fn raster, _opts ->
           send(owner, {:analysis_started, self()})

           receive do
             :finish -> Analysis.analyze(raster, colors: 3)
           end
         end,
         owner: owner},
        id: make_ref()
      )
    )

    file_select(runtime, "image_file_selected", "slow.bmp", "encoded")
    assert_receive {:analysis_started, task_pid}
    monitor = Process.monitor(task_pid)

    click(runtime, "cancel_load")
    assert_receive {:image_palette, :cancelled, 1}
    assert_receive {:DOWN, ^monitor, :process, ^task_pid, :killed}
    assert %{status: :idle, stage: "Analysis cancelled", job_id: 2} = assigns(runtime)

    send_view(runtime, {:image_loaded, 1, 10, 10, [%{hex: "#FFFFFF"}]})
    assert %{status: :idle, image: nil, palette: []} = assigns(runtime)
  end

  test "replaces active analysis and keeps only the newest result" do
    runtime = start_runtime!(App)
    task_supervisor = start_task_supervisor!()
    owner = self()
    first = solid_raster(255, 0, 0)
    second = solid_raster(0, 0, 255)

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator,
         runtime: runtime,
         task_supervisor: task_supervisor,
         decode: fn
           "first" -> {:ok, first}
           "second" -> {:ok, second}
         end,
         analyze: fn
           ^first, _opts ->
             send(owner, {:first_analysis_started, self()})

             receive do
               :finish -> Analysis.analyze(first, colors: 1)
             end

           ^second, opts ->
             Analysis.analyze(second, opts)
         end,
         owner: owner},
        id: make_ref()
      )
    )

    file_select(runtime, "image_file_selected", "first.bmp", "first")
    assert_receive {:first_analysis_started, first_task}
    monitor = Process.monitor(first_task)

    file_select(runtime, "image_file_selected", "second.bmp", "second")
    assert_receive {:DOWN, ^monitor, :process, ^first_task, :killed}
    assert_receive {:image_palette, :loaded, 2}

    assert %{status: :ready, source_name: "second.bmp", palette: [%{hex: "#0000FF"}]} =
             assigns(runtime)
  end

  test "handles deterministic display-side file cancellation" do
    runtime = start_runtime!(App)
    file_cancel(runtime, "image_file_selected")
    assert %{status: :idle, stage: "Selection cancelled"} = assigns(runtime)
  end

  test "reports file errors without requiring native image decoding" do
    runtime = start_runtime!(App, args: %{path: "/missing/image.png"})
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

  defp solid_raster(red, green, blue) do
    pixel = <<red, green, blue, 255>>
    GPUI.Raster.new(2, 2, pixel <> pixel <> pixel <> pixel)
  end
end
