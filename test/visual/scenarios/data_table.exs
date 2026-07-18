defmodule GPUITest.Visual.DataTable.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col w-[760px] h-[500px] gap-3 p-4 bg-slate-900">
      <text class="text-white text-2xl font-semibold">Source-backed data table</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Fixed headers · numeric alignment · wide horizontal content</text>
      <UI.data_table
        id="visual-table"
        label="Runtime records"
        selected={assigns.selected}
        selected_column={assigns.selected_column}
        reveal={assigns.selected}
        sort_column={assigns.sort_column}
        sort_direction={assigns.sort_direction}
        item_height={48}
        header_height={44}
        phx-change="row_selected"
        phx-cell-change="cell_selected"
        phx-sort="table_sorted"
        class="h-[410px]"
      >
        {columns() ++ Enum.map(assigns.rows, &row/1)}
      </UI.data_table>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("row_selected", %{value: selected}, assigns),
    do: {:noreply, %{assigns | selected: selected}}

  def handle_event("cell_selected", %{value: [selected, column]}, assigns),
    do: {:noreply, %{assigns | selected: selected, selected_column: column}}

  def handle_event("table_sorted", %{value: column}, assigns) do
    direction =
      if assigns.sort_column == column and assigns.sort_direction == "ascending",
        do: "descending",
        else: "ascending"

    {:noreply, %{assigns | sort_column: column, sort_direction: direction}}
  end

  defp columns do
    [
      UI.table_column(%{id: "process", label: "Process", width: 150}),
      UI.table_column(%{id: "name", label: "Registered name", width: 220, sortable: true}),
      UI.table_column(%{
        id: "memory",
        label: "Memory",
        width: 140,
        align: "right",
        sortable: true
      }),
      UI.table_column(%{
        id: "mailbox",
        label: "Mailbox",
        width: 130,
        align: "right",
        sortable: true
      }),
      UI.table_column(%{id: "reductions", label: "Reductions", width: 170, align: "right"}),
      UI.table_column(%{id: "node", label: "Node", width: 220})
    ]
  end

  defp row(row) do
    UI.table_row(%{
      id: row.id,
      children: [row.process, row.name, row.memory, row.mailbox, row.reductions, row.node]
    })
  end
end

defmodule GPUITest.Visual.DataTable.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    rows =
      Enum.map(1..40, fn number ->
        %{
          id: "process-#{number}",
          process: "<0.#{number + 40}.0>",
          name: if(rem(number, 3) == 0, do: "worker_#{number}", else: "unregistered"),
          memory: "#{number * 12} KB",
          mailbox: Integer.to_string(rem(number * 7, 31)),
          reductions: Integer.to_string(number * 18_421),
          node: "nonode@nohost"
        }
      end)

    {:ok,
     [
       window "GPUI Data Table Visual" do
         size(760, 500)

         root(GPUITest.Visual.DataTable.View,
           rows: rows,
           selected: nil,
           selected_column: "process",
           sort_column: "memory",
           sort_direction: "descending"
         )
       end
     ]}
  end
end

defmodule GPUITest.Visual.DataTable.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :data_table

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GPUITest.Visual.DataTable.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "GPUI Data Table Visual"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "table"},
      %{
        name: "selected-cell",
        actions: [
          {:dispatch,
           %{
             type: :change,
             window_id: 1,
             event: "cell_selected",
             value: ["process-6", "memory"]
           }}
        ]
      },
      %{
        name: "sorted-name",
        actions: [
          {:dispatch, %{type: :change, window_id: 1, event: "table_sorted", value: "name"}}
        ]
      }
    ]
  end
end
