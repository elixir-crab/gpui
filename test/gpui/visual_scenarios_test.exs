for scenario <- ~w(component_gallery image_palette process_explorer virtual_list) do
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
             %{name: "loading-replacement", actions: [load, progress]}
           ] = scenario.captures()

    assert {:dispatch, %{event: "select_color:#F59E0B"}} = selection
    assert {:dispatch, %{event: "load_image"}} = load
    assert {:send_view, 1, {:image_progress, 1, 45, "Sampling pixels"}} = progress

    runtime = start_gpui!(scenario.app(), args: scenario.args(:dark))

    assert %{
             status: :ready,
             image: %GPUI.Raster{width: 360, height: 280},
             palette: palette
           } = assigns(runtime)

    assert Enum.any?(palette, &(&1.hex == "#F59E0B"))
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

    assert [%{name: "processes"}, %{name: "selected-process", actions: [action]}] =
             scenario.captures()

    assert {:dispatch, %{event: "process_selected", value: "<0.50.0>"}} = action
  end
end
