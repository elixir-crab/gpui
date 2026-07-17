defmodule GPUITest.Visual.VirtualList.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col w-[480px] h-[520px] gap-3 p-4 bg-slate-900">
      <text class="text-white text-2xl font-semibold">Virtualized collection</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>100 rows · 9 visible elements</text>
      <UI.virtual_list
        id="visual-list"
        label="Numbered rows"
        selected={assigns.selected}
        reveal={assigns.selected}
        reveal_strategy="center"
        item_height={48}
        phx-change="row_selected"
        class="h-[432px]"
      >
        {Enum.map(assigns.items, &row(&1, assigns.selected))}
      </UI.virtual_list>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("row_selected", %{value: selected}, assigns),
    do: {:noreply, %{assigns | selected: selected}}

  defp row(id, selected) do
    assigns = %{id: id, selected: id == selected}

    ~GPUI"""
    <UI.virtual_list_item id={assigns.id} style={row_style(assigns.selected)}>
      <div class="flex items-center justify-between h-[48px] px-4">
        <text class="text-white">{assigns.id}</text>
        <text style={[color: {:rgb, 0x94A3B8}]}>Stable row ID</text>
      </div>
    </UI.virtual_list_item>
    """
  end

  defp row_style(true), do: [background: {:rgb, 0x1D4ED8}]
  defp row_style(false), do: [background: {:rgb, 0x111827}]
end

defmodule GPUITest.Visual.VirtualList.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "GPUI Virtual List Visual" do
         size(480, 520)

         root(GPUITest.Visual.VirtualList.View,
           items: Enum.map(1..100, &"row-#{String.pad_leading(Integer.to_string(&1), 3, "0")}"),
           selected: nil
         )
       end
     ]}
  end
end

defmodule GPUITest.Visual.VirtualList.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :virtual_list

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GPUITest.Visual.VirtualList.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "GPUI Virtual List Visual"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "initial-range"},
      %{
        name: "revealed-selection",
        actions: [
          {:dispatch, %{type: :change, window_id: 1, event: "row_selected", value: "row-096"}}
        ]
      }
    ]
  end
end
