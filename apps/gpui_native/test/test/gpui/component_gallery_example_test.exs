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
    change(runtime, "name_changed", "Grace Hopper")
    assert %{story: "input", name: "Grace Hopper", last_event: "name_changed"} = assigns(runtime)

    click(runtime, "story-select")
    select(runtime, "language_changed", "rust")
    assert %{story: "select", language: "rust"} = assigns(runtime)

    change(runtime, "search_changed", "diff")
    assert %{story: "code_viewer", query: "diff"} = assigns(runtime)
    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "gallery-code")
  end

  test "shows overlay stories independently" do
    runtime = start_runtime!(Examples.ComponentGallery.App, args: %{story: "dialog"})

    click(runtime, "show-dialog")

    assert %{story: "dialog", overlay: "dialog", last_event: "opened dialog"} = assigns(runtime)

    assert %{type: :ui_dialog, attrs: %{open: true}} =
             runtime |> tree() |> find!(id: "gallery-dialog")
  end

  test "keeps navigation and collection state in the view process" do
    runtime = start_runtime!(Examples.ComponentGallery.App, args: %{story: "tabs"})

    select(runtime, "tabs_changed", "settings")
    click(runtime, "story-accordion")
    change(runtime, "accordion_changed", ["account", "security"])
    click(runtime, "story-virtual_list")
    change(runtime, "list_selected", "item-12")
    click(runtime, "story-data_table")
    change(runtime, "table_selected", "events")
    click(runtime, "story-tree")
    change(runtime, "tree_selected", "runtime")

    assert %{
             tab: "settings",
             expanded: ["account", "security"],
             list_selected: "item-12",
             table_selected: "events",
             tree_selected: "runtime"
           } = assigns(runtime)
  end
end
