defmodule GPUI.Test.Native.CollectionsTest do
  use GPUI.Test, native: [size: {360, 240}]

  defmodule ListView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <UI.virtual_list
        id="records"
        label="Records"
        selected={assigns.selected}
        item_height={40}
        phx-change="record_selected"
        class="h-[200px]"
      >
        {Enum.map(assigns.items, &item/1)}
      </UI.virtual_list>
      """
    end

    defp item(id) do
      ~GPUI"""
      <UI.virtual_list_item id={id} disabled={id == "item-2"}>
        <div class="h-[40px]"><text>{id}</text></div>
      </UI.virtual_list_item>
      """
    end
  end

  defmodule SourceListView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      first = assigns.range.first
      last = min(assigns.range.last, assigns.total_count)
      items = if first < last, do: Enum.map(first..(last - 1), &item/1), else: []

      ~GPUI"""
      <UI.virtual_list
        id="source-records"
        label="Source records"
        selected={assigns.selected}
        selected_index={assigns.selected_index}
        total_count={assigns.total_count}
        offset={first}
        overscan={2}
        item_height={40}
        phx-change="source_selected"
        phx-range="source_range"
        class="h-[200px]"
      >
        {items}
      </UI.virtual_list>
      """
    end

    defp item(index) do
      id = "row-#{index}"

      ~GPUI"""
      <UI.virtual_list_item id={id}>
        <div class="h-[40px]"><text>{id}</text></div>
      </UI.virtual_list_item>
      """
    end
  end

  defmodule VariableView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <UI.virtual_collection
        id="variable-records"
        label="Variable records"
        follow={assigns.follow}
        follow_request={assigns.follow_request}
        phx-range="variable_range"
        class="h-[200px]"
      >
        {Enum.map(assigns.items, &item/1)}
      </UI.virtual_collection>
      """
    end

    defp item({id, revision, height}) do
      ~GPUI"""
      <UI.virtual_item id={id} revision={revision} style={[height: {:px, height}]}>
        <text>{id}</text>
      </UI.virtual_item>
      """
    end
  end

  test "uniform list keyboard navigation skips disabled items", %{ui: ui} do
    render(ui, ListView, selected: "item-1", items: Enum.map(1..20, &"item-#{&1}"))
    focus(ui, "records")
    press(ui, :arrow_down)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "record_selected", value: "item-3"}}}

    render(ui, ListView, selected: "item-3", items: Enum.map(1..20, &"item-#{&1}"))
    focus(ui, "records")
    press(ui, :arrow_up)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "record_selected", value: "item-1"}}}
  end

  test "source-backed list emits bounded ranges after scrolling", %{ui: ui} do
    render(ui, SourceListView,
      selected: "row-0",
      selected_index: 0,
      total_count: 1_000,
      range: %{first: 0, last: 20}
    )

    assert_receive {:gpui, ^ui, {:event, %{type: :range, event: "source_range", value: initial}}}
    assert initial.first == 0
    assert initial.last <= 20

    scroll(ui, "source-records", delta: {0, -240})

    assert_receive {:gpui, ^ui, {:event, %{type: :range, event: "source_range", value: range}}}
    assert range.first > initial.first
    assert range.first < range.last
    assert range.last <= 1_000
  end

  test "variable collections survive empty, populated, resized, and empty transitions", %{ui: ui} do
    render(ui, VariableView, items: [], follow: "none", follow_request: 0)
    assert %{width: width, height: height} = bounds(ui, "variable-records")
    assert width > 0
    assert height > 0

    render(ui, VariableView,
      items: [{"one", 0, 32}, {"two", 0, 64}, {"three", 0, 48}],
      follow: "none",
      follow_request: 0
    )

    settle(ui)
    scroll(ui, "variable-records", delta: {0, -80})

    render(ui, VariableView,
      items: [{"one", 1, 80}, {"two", 0, 64}, {"three", 0, 48}, {"four", 0, 40}],
      follow: "tail",
      follow_request: 1
    )

    settle(ui)
    assert %{width: resized_width, height: resized_height} = bounds(ui, "variable-records")
    assert resized_width > 0
    assert resized_height > 0

    render(ui, VariableView, items: [], follow: "none", follow_request: 1)
    settle(ui)
    assert %{width: final_width, height: final_height} = bounds(ui, "variable-records")
    assert final_width > 0
    assert final_height > 0
  end
end
