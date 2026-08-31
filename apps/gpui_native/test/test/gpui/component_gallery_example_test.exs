GPUITest.Examples.load!(:component_gallery)

defmodule GPUI.ComponentGalleryExampleTest do
  use GPUI.Test, async: true

  test "navigates one-component stories and keeps values controlled" do
    runtime = start_runtime!(Examples.ComponentGallery.App)

    assert %{title: "GPUI Component Gallery", size: [1180, 760]} = window_snapshot(runtime)
    assert %{story: "welcome", query: "", event_count: 0} = assigns(runtime)

    click(runtime, "story-progress")
    assert %{type: :ui_progress} = runtime |> tree() |> find!(id: "gallery-progress")

    click(runtime, "story-input")
    change(runtime, "story:input:changed", "Grace Hopper")

    assert %{story: "input", story_states: %{"input" => %{name: "Grace Hopper"}}} =
             assigns(runtime)

    click(runtime, "story-select")
    select(runtime, "story:select:language", "rust")
    assert %{story: "select", story_states: %{"select" => %{language: "rust"}}} = assigns(runtime)

    change(runtime, "search_changed", "diff")
    assert %{story: "code_viewer", query: "diff"} = assigns(runtime)
    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "gallery-code")
  end

  test "shows overlay stories independently" do
    runtime = start_runtime!(Examples.ComponentGallery.App, args: %{story: "dialog"})

    click(runtime, "story:dialog:open")

    assert %{story: "dialog", story_states: %{"dialog" => %{open: true}}} = assigns(runtime)

    assert %{type: :ui_dialog, attrs: %{open: true}} =
             runtime |> tree() |> find!(id: "gallery-dialog")
  end

  test "keeps navigation and collection state in the view process" do
    runtime = start_runtime!(Examples.ComponentGallery.App, args: %{story: "tabs"})

    select(runtime, "story:tabs:changed", "settings")
    click(runtime, "story-accordion")
    change(runtime, "story:accordion:changed", ["account", "security"])
    click(runtime, "story-virtual_list")
    change(runtime, "story:virtual_list:selected", "item-12")
    click(runtime, "story-data_table")
    change(runtime, "story:data_table:selected", "events")
    click(runtime, "story-tree")
    change(runtime, "story:tree:selected", "runtime")

    assert %{
             story_states: %{
               "tabs" => %{value: "settings"},
               "accordion" => %{expanded: ["account", "security"]},
               "virtual_list" => %{selected: "item-12"},
               "data_table" => %{selected: "events"},
               "tree" => %{selected: "runtime"}
             }
           } = assigns(runtime)
  end
end
