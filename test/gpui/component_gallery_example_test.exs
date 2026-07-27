GPUITest.Examples.load!(:component_gallery)

defmodule GPUI.ComponentGalleryExampleTest do
  use GPUI.Test, async: true

  test "navigates searchable stories and keeps form controls controlled" do
    runtime = start_gpui!(Examples.ComponentGallery.App)

    assert %{title: "GPUI Component Gallery", size: [1280, 820]} = window_snapshot(runtime)
    assert %{story: "actions", query: ""} = assigns(runtime)
    assert %{type: :ui_progress} = runtime |> tree() |> find!(id: "gallery-progress")

    click(runtime, "story-forms")
    change(runtime, "name_changed", "Grace Hopper")
    select(runtime, "language_changed", "rust")
    toggle(runtime, "notifications_changed", false)
    slide(runtime, "volume_changed", 40.0)

    assert %{
             story: "forms",
             name: "Grace Hopper",
             language: "rust",
             notifications: false,
             volume: 40.0
           } = assigns(runtime)

    change(runtime, "search_changed", "diff")
    assert %{story: "code", query: "diff"} = assigns(runtime)
    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "gallery-code")
  end

  test "covers overlays, navigation, and collection selection" do
    runtime = start_gpui!(Examples.ComponentGallery.App, args: %{story: "overlays"})

    click(runtime, "show-dialog")
    assert %{overlay: "dialog"} = assigns(runtime)

    assert %{type: :ui_dialog, attrs: %{open: true}} =
             runtime |> tree() |> find!(id: "gallery-dialog")

    click(runtime, "story-navigation")
    select(runtime, "tabs_changed", "settings")
    change(runtime, "accordion_changed", ["account", "security"])
    assert %{tab: "settings", expanded: ["account", "security"]} = assigns(runtime)

    click(runtime, "story-collections")
    change(runtime, "list_selected", "item-12")
    change(runtime, "table_selected", "events")
    change(runtime, "tree_selected", "runtime")

    assert %{
             list_selected: "item-12",
             table_selected: "events",
             tree_selected: "runtime"
           } = assigns(runtime)
  end
end
