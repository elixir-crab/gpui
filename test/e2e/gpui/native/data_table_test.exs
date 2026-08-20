defmodule GPUI.Native.DataTableE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  @moduletag :e2e

  defmodule TableView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      first = min(assigns.range.first, assigns.total_count)
      last = assigns.range.last |> max(first) |> min(assigns.total_count)

      rows =
        if first < last do
          Enum.map(first..(last - 1), &row(&1, assigns.target_index))
        else
          []
        end

      ~GPUI"""
      <div class="w-[640px] h-[420px] bg-slate-900 p-2">
        <UI.data_table
          id="source-table"
          label="Source-backed records"
          selected={assigns.selected}
          selected_index={assigns.selected_index}
          selected_column={assigns.selected_column}
          reveal={assigns.reveal}
          reveal_index={assigns.reveal_index}
          sort_column={assigns.sort_column}
          sort_direction={assigns.sort_direction}
          total_count={assigns.total_count}
          offset={first}
          overscan={10}
          item_height={44}
          header_height={40}
          phx-change="row_selected"
          phx-cell-change="cell_selected"
          phx-sort="table_sorted"
          phx-range="table_range"
          class="h-[400px]"
        >
          {columns() ++ rows}
        </UI.data_table>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("table_range", %{value: range}, assigns),
      do: {:noreply, %{assigns | range: range}}

    def handle_event("row_selected", %{value: selected}, assigns) do
      index = row_index(selected, assigns.target_index)

      {:noreply,
       %{
         assigns
         | selected: selected,
           selected_index: index,
           reveal: selected,
           reveal_index: index
       }}
    end

    def handle_event("cell_selected", %{value: [row_id, column_id]}, assigns) do
      index = row_index(row_id, assigns.target_index)

      {:noreply,
       %{
         assigns
         | selected: row_id,
           selected_index: index,
           selected_column: column_id,
           reveal: row_id,
           reveal_index: index
       }}
    end

    def handle_event("table_sorted", %{value: column_id}, assigns) do
      direction =
        if assigns.sort_column == column_id and assigns.sort_direction == "ascending",
          do: "descending",
          else: "ascending"

      {:noreply, %{assigns | sort_column: column_id, sort_direction: direction}}
    end

    defp columns do
      [
        UI.table_column(%{id: "name", label: "Name", width: 220, sortable: true}),
        UI.table_column(%{
          id: "memory",
          label: "Memory",
          width: 140,
          align: "right",
          sortable: true
        }),
        UI.table_column(%{id: "mailbox", label: "Mailbox", width: 140, align: "right"}),
        UI.table_column(%{id: "reductions", label: "Reductions", width: 180, align: "right"}),
        UI.table_column(%{id: "status", label: "Status", width: 160}),
        UI.table_column(%{id: "node", label: "Node", width: 220})
      ]
    end

    defp row(index, target_index) do
      id = if index == target_index, do: "target", else: "row-#{index + 1}"

      UI.table_row(%{
        id: id,
        children: [
          "record-#{index + 1}",
          "#{index + 1} KB",
          Integer.to_string(rem(index, 17)),
          Integer.to_string(index * 101),
          "running",
          "nonode@nohost"
        ]
      })
    end

    defp row_index("target", target_index), do: target_index

    defp row_index("row-" <> number, _target_index),
      do: String.to_integer(number) - 1
  end

  defmodule TableApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Data Table E2E" do
           size(640, 420)

           root(TableView,
             total_count: 100_000,
             range: %{first: 0, last: 32},
             selected: "target",
             selected_index: 99_999,
             selected_column: "name",
             reveal: "target",
             reveal_index: 99_999,
             target_index: 99_999,
             sort_column: "name",
             sort_direction: "ascending"
           )
         end
       ]}
    end
  end

  test "virtualizes wide source-backed grids with sorting and cell navigation" do
    {:ok, runtime} = GPUI.Runtime.start_link(app: TableApp, poll_interval: 10)
    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    native_window_id = Desktop.window_id!("GPUI Data Table E2E")
    Desktop.await_frame!(runtime, 1, native_window_id)

    range = current_or_await_distant_range(runtime)
    assert range.first > 99_900
    assert range.last == 100_000
    Desktop.await_frame!(runtime, 1, native_window_id)

    snapshot = GPUI.Runtime.snapshot(runtime)
    rows = snapshot |> GPUI.Test.tree() |> GPUI.Test.all(type: :ui_table_row)
    assert Enum.count_until(rows, 33) <= 32
    assert Enum.any?(rows, &match?(%{attrs: %{id: "target"}}, &1))

    Desktop.click!(native_window_id, 110, 22)
    assert await_event(runtime, "table_sorted") == "name"

    Desktop.click!(native_window_id, 110, 70)
    events = await_events(runtime, ~w(row_selected cell_selected))
    assert Enum.find(events, &(&1.event == "row_selected")).value
    assert [_row, "name"] = Enum.find(events, &(&1.event == "cell_selected")).value

    Desktop.key!(native_window_id, "Right")
    assert [_row, "memory"] = await_event(runtime, "cell_selected")

    Desktop.key!(native_window_id, "Up")
    assert selected = await_event(runtime, "row_selected")
    assert selected != "target"
    assert Process.alive?(runtime)
  end

  defp current_or_await_distant_range(runtime) do
    range = runtime |> GPUI.Runtime.snapshot() |> hd_window_assigns() |> Map.fetch!(:range)
    if range.last > 99_900, do: range, else: await_distant_range(runtime)
  end

  defp hd_window_assigns(snapshot),
    do: snapshot.windows |> hd() |> get_in([:root, :assigns])

  defp await_distant_range(runtime) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find_value(events, fn
               %{type: :range, event: "table_range", value: %{last: last} = range}
               when last > 99_900 ->
                 range

               _event ->
                 nil
             end) do
          nil -> await_distant_range(runtime)
          range -> range
        end
    after
      5_000 -> flunk("data table did not request the distant selected range")
    end
  end

  defp await_events(runtime, names) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        if Enum.all?(names, &Enum.any?(events, fn event -> event.event == &1 end)) do
          events
        else
          await_events(runtime, names)
        end
    after
      5_000 -> flunk("data table did not emit #{Enum.join(names, ", ")}")
    end
  end

  defp await_event(runtime, name) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find(events, &(&1.event == name)) do
          nil -> await_event(runtime, name)
          event -> event.value
        end
    after
      5_000 -> flunk("data table did not emit #{name}")
    end
  end
end
