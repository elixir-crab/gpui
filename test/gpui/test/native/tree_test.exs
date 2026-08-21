defmodule GPUI.Test.Native.TreeTest do
  use GPUI.Test, native: [size: {360, 240}]

  defmodule TreeView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <UI.tree
        id="files"
        label="Files"
        selected={assigns.selected}
        total_count={4}
        offset={0}
        item_height={40}
        phx-change="tree_selected"
        phx-toggle="tree_toggled"
        class="h-[200px]"
      >
        <UI.tree_item id="lib" level={1} branch={true} expanded={assigns.expanded}>
          <text>lib</text>
        </UI.tree_item>
        <UI.tree_item id="disabled" level={2} parent_id="lib" disabled={true}>
          <text>disabled.ex</text>
        </UI.tree_item>
        <UI.tree_item id="app" level={2} parent_id="lib">
          <text>app.ex</text>
        </UI.tree_item>
        <UI.tree_item id="readme" level={1}>
          <text>README</text>
        </UI.tree_item>
      </UI.tree>
      """
    end
  end

  defp render_tree(ui, opts \\ []) do
    render(ui, TreeView, Keyword.merge([selected: "lib", expanded: false], opts))
  end

  test "expands branches and skips disabled children", %{ui: ui} do
    render_tree(ui)
    focus(ui, "files")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "tree_toggled", value: "lib"}}}

    render_tree(ui, expanded: true)
    focus(ui, "files")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "tree_selected", value: "app"}}}
  end

  test "linear navigation skips disabled items", %{ui: ui} do
    render_tree(ui, expanded: true)
    focus(ui, "files")
    press(ui, :arrow_down)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "tree_selected", value: "app"}}}

    render_tree(ui, selected: "app", expanded: true)
    focus(ui, "files")
    press(ui, :arrow_down)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "tree_selected", value: "readme"}}}
  end
end
