defmodule GPUI.Native.TreeE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

  @moduletag :e2e

  defmodule TreeView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      first = min(assigns.range.first, assigns.total_count)
      last = assigns.range.last |> max(first) |> min(assigns.total_count)

      items =
        if first < last do
          Enum.map(first..(last - 1), &item(&1, assigns))
        else
          []
        end

      ~GPUI"""
      <div class="w-[420px] h-[420px] bg-slate-900 text-white">
        <UI.tree
          id="source-tree"
          label="Source-backed tree"
          selected={assigns.selected}
          selected_index={assigns.selected_index}
          reveal={assigns.reveal}
          reveal_index={assigns.reveal_index}
          total_count={assigns.total_count}
          offset={first}
          overscan={10}
          item_height={40}
          phx-change="tree_selected"
          phx-toggle="tree_toggled"
          phx-range="tree_range"
          class="h-[400px]"
        >
          {items}
        </UI.tree>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("tree_range", %{value: range}, assigns),
      do: {:noreply, %{assigns | range: range}}

    def handle_event("tree_selected", %{value: selected}, assigns) do
      index = if selected == "target", do: assigns.target_index, else: item_index(selected)

      {:noreply,
       %{
         assigns
         | selected: selected,
           selected_index: index,
           reveal: selected,
           reveal_index: index
       }}
    end

    def handle_event("tree_toggled", %{value: "target"}, assigns),
      do: {:noreply, %{assigns | expanded: not assigns.expanded}}

    defp item(index, assigns) do
      id = if index == assigns.target_index, do: "target", else: "item-#{index}"

      item_assigns = %{
        id: id,
        position: index + 1,
        set_size: assigns.total_count,
        target: id == "target",
        expanded: id == "target" and assigns.expanded
      }

      ~GPUI"""
      <UI.tree_item
        id={item_assigns.id}
        level={1}
        branch={item_assigns.target}
        expanded={item_assigns.expanded}
        position={item_assigns.position}
        set_size={item_assigns.set_size}
      >
        <div class="flex items-center h-[40px] px-3">
          <text class="text-white">{item_assigns.id}</text>
        </div>
      </UI.tree_item>
      """
    end

    defp item_index("item-" <> index), do: String.to_integer(index)
  end

  defmodule TreeApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Tree E2E" do
           size(420, 420)

           root(TreeView,
             total_count: 100_000,
             range: %{first: 0, last: 32},
             selected: "target",
             selected_index: 99_999,
             reveal: "target",
             reveal_index: 99_999,
             target_index: 99_999,
             expanded: false
           )
         end
       ]}
    end
  end

  test "desktop renders a distant virtualized tree and delivers pointer input", %{
    desktop: desktop
  } do
    runtime =
      start_runtime!(desktop,
        app: TreeApp,
        poll_interval: 10,
        display_opts: [theme: :dark]
      )

    native_window_id = Desktop.window!(desktop, "GPUI Tree E2E")
    Desktop.await_frame!(desktop, runtime, 1, native_window_id)

    current_range =
      runtime |> GPUI.Runtime.snapshot() |> GPUI.Test.assigns() |> Map.fetch!(:range)

    range =
      if current_range.last == 100_000,
        do: current_range,
        else: await_range(runtime, &(&1.last == 100_000))

    assert range.first > 99_900
    Desktop.await_frame!(desktop, runtime, 1, native_window_id)
    Desktop.capture_fixture!(desktop, native_window_id, "tree")

    loaded_items =
      runtime
      |> GPUI.Runtime.snapshot()
      |> GPUI.Test.tree()
      |> GPUI.Tree.all(type: :ui_tree_item)

    assert Enum.count(loaded_items) <= 32
    assert Enum.any?(loaded_items, &match?(%{attrs: %{id: "target"}}, &1))

    Desktop.click!(desktop, native_window_id, at: {120, 200})
    assert is_binary(await_value(runtime, "tree_selected"))
    assert Process.alive?(runtime)
  end

  defp await_range(runtime, predicate) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find_value(events, fn
               %{type: :range, event: "tree_range", value: range} ->
                 if predicate.(range), do: range

               _event ->
                 nil
             end) do
          nil -> await_range(runtime, predicate)
          range -> range
        end
    after
      5_000 -> flunk("tree did not emit the expected source range")
    end
  end

  defp await_value(runtime, event_name) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find_value(events, fn
               %{type: :change, event: ^event_name, value: value} -> value
               _event -> nil
             end) do
          nil -> await_value(runtime, event_name)
          value -> value
        end
    after
      5_000 -> flunk("tree did not emit #{event_name}")
    end
  end
end
