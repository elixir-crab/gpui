defmodule GPUI.Test.Native.DataTableTest do
  use GPUI.Test, native: [size: {480, 260}]

  defmodule TableView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <UI.data_table
        id="records"
        label="Records"
        selected={assigns.selected}
        selected_column={assigns.selected_column}
        sort_column={assigns.sort_column}
        sort_direction={assigns.sort_direction}
        total_count={3}
        offset={0}
        item_height={44}
        header_height={40}
        phx-change="row_selected"
        phx-cell-change="cell_selected"
        phx-sort="table_sorted"
        class="h-[220px]"
      >
        <UI.table_column id="name" label="Name" width={220} sortable={true} />
        <UI.table_column id="memory" label="Memory" width={140} sortable={true} />
        <UI.table_row id="alpha"><text>alpha</text><text>1 KB</text></UI.table_row>
        <UI.table_row id="disabled" disabled={true}><text>disabled</text><text>2 KB</text></UI.table_row>
        <UI.table_row id="omega"><text>omega</text><text>3 KB</text></UI.table_row>
      </UI.data_table>
      """
    end
  end

  defp render_table(ui, opts \\ []) do
    render(
      ui,
      TableView,
      Keyword.merge(
        [
          selected: "alpha",
          selected_column: "name",
          sort_column: "name",
          sort_direction: "ascending"
        ],
        opts
      )
    )
  end

  test "keyboard row navigation skips disabled rows", %{ui: ui} do
    render_table(ui)
    focus(ui, "records")
    press(ui, :arrow_down)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "row_selected", value: "omega"}}}

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "cell_selected", value: ["omega", "name"]}}}
  end

  test "keyboard cell navigation emits controlled row and column IDs", %{ui: ui} do
    render_table(ui)
    focus(ui, "records")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "cell_selected", value: ["alpha", "memory"]}}}

    render_table(ui, selected_column: "memory")
    focus(ui, "records")
    press(ui, :arrow_left)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "cell_selected", value: ["alpha", "name"]}}}
  end
end
