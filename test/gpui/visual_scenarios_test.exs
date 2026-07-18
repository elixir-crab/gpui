for scenario <-
      ~w(code_viewer component_gallery focus_timer git_repository_browser hello_window image_palette process_explorer settings_form virtual_list) do
  Code.require_file("../visual/scenarios/#{scenario}.exs", __DIR__)
end

defmodule GPUI.VisualScenariosTest do
  use GPUI.Test, async: true

  test "component gallery declares deterministic controlled states" do
    scenario = GPUITest.Visual.ComponentGallery.Scenario

    assert scenario.id() == :component_gallery
    assert scenario.title() == "GPUI Visual Gallery"

    assert Enum.map(scenario.captures(), & &1.name) == [
             "components",
             "popover",
             "tooltip",
             "dialog",
             "dropdown-menu"
           ]

    runtime = start_gpui!(scenario.app(), args: scenario.args(:dark))
    assert %{overlay: nil, theme: :dark} = assigns(runtime)
  end

  test "code viewer scenario covers code, diff, selection, and long lines" do
    scenario = GPUITest.Visual.CodeViewer.Scenario

    assert Enum.map(scenario.captures(), & &1.name) == [
             "code",
             "diff",
             "selection",
             "long-lines"
           ]

    runtime = start_gpui!(scenario.app(), args: scenario.args(:dark))
    assert %{mode: :code, selected: nil} = assigns(runtime)
    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "visual-code")
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

  test "virtual list scenario reveals a deterministic distant selection" do
    scenario = GPUITest.Visual.VirtualList.Scenario

    assert [%{name: "initial-range"}, %{name: "revealed-selection", actions: [action]}] =
             scenario.captures()

    assert {:dispatch, %{event: "row_selected", value: "row-096"}} = action
    runtime = start_gpui!(scenario.app(), args: scenario.args(:dark))
    assert %{items: ["row-001" | _rows] = items, selected: nil} = assigns(runtime)
    assert List.last(items) == "row-100"
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

    runtime = start_gpui!(scenario.app(), args: scenario.args(:dark))

    assert %{
             status: :ready,
             image: %GPUI.Raster{width: 360, height: 280},
             palette: palette
           } = assigns(runtime)

    assert Enum.any?(palette, &(&1.hex == "#F59E0B"))
  end

  test "git repository browser scenario uses fixed hierarchy and diff transitions" do
    scenario = GPUITest.Visual.GitRepositoryBrowser.Scenario
    %{repository: repository, preview: preview} = scenario.args(:dark)

    assert repository.root == "/workspace/gpui"
    assert repository.counts == %{total: 16, clean: 10, changed: 6}
    assert Enum.count_until(preview.lines, 101) == 101

    assert [
             %{name: "repository"},
             %{name: "filtered-untracked", actions: [filter, filtered_slice]},
             %{
               name: "selected-readme",
               actions: [all, all_slice, select, selected_slice, loaded]
             }
           ] = scenario.captures()

    assert {:dispatch, %{event: "status_filter_changed", value: "untracked"}} = filter
    assert {:send_view_from, 1, filtered_builder} = filtered_slice
    assert {:tree_slice, 7, %{total: 3}} = filtered_builder.(%{tree_generation: 7})
    assert {:dispatch, %{event: "status_filter_changed", value: "all"}} = all
    assert {:send_view_from, 1, all_builder} = all_slice
    assert {:tree_slice, 8, %{total: 21}} = all_builder.(%{tree_generation: 8})
    assert {:dispatch, %{event: "tree_selected", value: "file:README.md"}} = select
    assert {:send_view_from, 1, selected_builder} = selected_slice

    assert {:tree_slice, 9, %{selected_index: selected_index}} =
             selected_builder.(%{tree_generation: 9})

    assert is_integer(selected_index)
    assert {:send_view_from, 1, preview_builder} = loaded

    assert {:preview_loaded, 3, 4, %{path: "README.md"}, _slice} =
             preview_builder.(%{preview_job: 3, preview_generation: 4})
  end

  test "process explorer scenario uses fixed data and transitions" do
    scenario = GPUITest.Visual.ProcessExplorer.Scenario
    %{processes: processes} = scenario.args(:dark)

    assert Enum.map(processes, & &1.pid) == [
             "<0.50.0>",
             "<0.45.0>",
             "<0.101.0>",
             "<0.188.0>",
             "<0.147.0>",
             "<0.0.0>",
             "<0.53.0>",
             "<0.72.0>"
           ]

    assert [
             %{name: "processes"},
             %{name: "selected-process", actions: [selection]},
             %{name: "filtered-empty", actions: [filter]}
           ] = scenario.captures()

    assert {:dispatch, %{event: "process_selected", value: "<0.50.0>"}} = selection
    assert {:dispatch, %{event: "filter_changed", value: "no matches"}} = filter
  end
end
