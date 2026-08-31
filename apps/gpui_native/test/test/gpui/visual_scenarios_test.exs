for scenario <-
      ~w(beam_control_room component_gallery controlled_form elixir_workbench focus_timer hello_window image_lab music_library) do
  GPUI.Dev.Visual.ScenarioLoader.load!(scenario)
end

defmodule GPUI.VisualScenariosTest do
  use GPUI.Test, async: true

  test "component gallery declares deterministic controlled states" do
    scenario = GPUITest.Visual.ComponentGallery.Scenario

    assert scenario.id() == :component_gallery
    assert scenario.title() == "GPUI Component Gallery"

    assert Enum.map(scenario.captures(), & &1.name) == [
             "welcome",
             "button",
             "progress",
             "input",
             "select",
             "checkbox",
             "switch",
             "radio",
             "slider",
             "popover",
             "tooltip",
             "dialog",
             "menu",
             "tabs",
             "accordion",
             "virtual-list",
             "data-table",
             "tree",
             "code-viewer"
           ]

    runtime = start_runtime!(scenario.app(), args: scenario.args(:dark))
    assert %{story: "welcome", story_states: %{"welcome" => %{}}} = assigns(runtime)
  end

  test "getting-started scenarios expose deterministic polished states" do
    assert [%{name: "hello-window"}] = GPUITest.Visual.HelloWindow.Scenario.captures()

    assert Enum.map(GPUITest.Visual.FocusTimer.Scenario.captures(), & &1.name) == [
             "ready",
             "running",
             "paused",
             "complete"
           ]

    assert Enum.map(GPUITest.Visual.ControlledForm.Scenario.captures(), & &1.name) == [
             "saved",
             "validation-error"
           ]
  end

  test "Control Room and Workbench scenarios cover their product surfaces" do
    control_room = GPUITest.Visual.BeamControlRoom.Scenario

    assert Enum.map(control_room.captures(), & &1.name) == [
             "runtime-health",
             "selected-process",
             "filtered-processes"
           ]

    control_room_runtime = start_runtime!(control_room.app(), args: control_room.args(:dark))
    assert %{run_queue: 2, schedulers: 8, paused: false} = assigns(control_room_runtime)

    assert %{type: :ui_data_table} =
             control_room_runtime |> tree() |> find!(id: "control-room-processes")

    workbench = GPUITest.Visual.ElixirWorkbench.Scenario

    assert Enum.map(workbench.captures(), & &1.name) == [
             "repository-and-console",
             "selected-diff",
             "command-palette"
           ]

    workbench_runtime = start_runtime!(workbench.app(), args: workbench.args(:dark))
    assert %{selected_id: "file:README.md", command_open: false} = assigns(workbench_runtime)
    assert %{type: :ui_tree} = workbench_runtime |> tree() |> find!(id: "workbench-tree")

    assert %{type: :ui_code_viewer} =
             workbench_runtime |> tree() |> find!(id: "workbench-code")
  end

  test "Image Lab scenario uses fixed raster data and controlled selection" do
    scenario = GPUITest.Visual.ImageLab.Scenario

    assert [
             %{name: "ready"},
             %{name: "selected-color", actions: [selection]},
             %{name: "copied-css", actions: [copied]},
             %{name: "loading-replacement", actions: [load, progress]},
             %{name: "cancelled-analysis", actions: [cancel]}
           ] = scenario.captures()

    assert {:dispatch, %{event: "select_color:#F59E0B"}} = selection
    assert {:dispatch, %{event: "palette_copied"}} = copied
    assert {:dispatch, %{event: "load_image"}} = load
    assert {:send_view, 1, {:image_progress, 1, 45, "Sampling pixels"}} = progress
    assert {:dispatch, %{event: "cancel_load"}} = cancel

    runtime = start_runtime!(scenario.app(), args: scenario.args(:dark))

    assert %{
             status: :ready,
             image: %GPUI.Raster{width: 360, height: 280},
             palette: palette
           } = assigns(runtime)

    assert Enum.any?(palette, &(&1.hex == "#F59E0B"))
  end
end
