for scenario <-
      ~w(beam_observatory component_gallery elixir_workbench focus_timer hello_window image_palette music_library settings_form) do
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
             "radio",
             "dialog",
             "data-table",
             "code-viewer"
           ]

    runtime = start_runtime!(scenario.app(), args: scenario.args(:dark))
    assert %{story: "welcome", overlay: nil} = assigns(runtime)
  end

  test "getting-started scenarios expose deterministic polished states" do
    assert [%{name: "hello-window"}] = GPUITest.Visual.HelloWindow.Scenario.captures()

    assert Enum.map(GPUITest.Visual.FocusTimer.Scenario.captures(), & &1.name) == [
             "ready",
             "running",
             "paused",
             "complete"
           ]

    assert Enum.map(GPUITest.Visual.SettingsForm.Scenario.captures(), & &1.name) == [
             "settings",
             "unsaved-paper-theme",
             "review-dialog"
           ]
  end

  test "consolidated Observatory and Workbench scenarios cover their product surfaces" do
    observatory = GPUITest.Visual.BeamObservatory.Scenario

    assert Enum.map(observatory.captures(), & &1.name) == [
             "runtime-health",
             "selected-process",
             "filtered-processes"
           ]

    observatory_runtime = start_runtime!(observatory.app(), args: observatory.args(:dark))
    assert %{run_queue: 2, schedulers: 8, paused: false} = assigns(observatory_runtime)

    assert %{type: :ui_data_table} =
             observatory_runtime |> tree() |> find!(id: "observatory-processes")

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

  test "image palette scenario uses fixed raster data and controlled selection" do
    scenario = GPUITest.Visual.ImagePalette.Scenario

    assert [
             %{name: "palette-ready"},
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
