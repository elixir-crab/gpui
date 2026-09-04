defmodule GPUI.Native.VirtualListE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

  @moduletag :e2e

  defmodule ListView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="w-[420px] h-[420px] bg-slate-900 text-white">
        <UI.virtual_list
          id="large-list"
          label="Large item list"
          selected={assigns.selected}
          reveal={assigns.reveal}
          reveal_strategy={assigns.reveal_strategy}
          item_height={40}
          phx-change="item_selected"
          class="h-[400px]"
        >
          {Enum.map(assigns.items, &item(&1, assigns.selected))}
        </UI.virtual_list>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("item_selected", %{value: selected}, assigns),
      do: {:noreply, %{assigns | selected: selected, reveal: selected}}

    @impl GPUI.View
    def handle_info({:replace_items, items}, assigns) do
      selected = if assigns.selected in items, do: assigns.selected
      {:noreply, %{assigns | items: items, selected: selected, reveal: selected}}
    end

    defp item(id, selected) do
      assigns = %{id: id, selected: id == selected, disabled: id == "item-2"}

      ~GPUI"""
      <UI.virtual_list_item
        id={assigns.id}
        disabled={assigns.disabled}
        style={item_style(assigns.selected)}
      >
        <div class="flex items-center h-[40px] px-3">
          <text class="text-white">{assigns.id}</text>
        </div>
      </UI.virtual_list_item>
      """
    end

    defp item_style(true), do: [background: {:rgb, 0x1D4ED8}]
    defp item_style(false), do: [background: {:rgb, 0x111827}]
  end

  defmodule SourceListView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      first = min(assigns.range.first, assigns.total_count)
      last = assigns.range.last |> max(first) |> min(assigns.total_count)

      items =
        if first < last do
          Enum.map(first..(last - 1), &source_item(&1, assigns.target_index))
        else
          []
        end

      ~GPUI"""
      <div class="w-[420px] h-[420px] bg-slate-900 text-white">
        <UI.virtual_list
          id="source-list"
          label="Source-backed items"
          selected={assigns.selected}
          selected_index={assigns.selected_index}
          reveal={assigns.reveal}
          reveal_index={assigns.reveal_index}
          total_count={assigns.total_count}
          offset={first}
          overscan={10}
          item_height={40}
          phx-change="source_selected"
          phx-range="source_range"
          style={[height: {:px, assigns.height}]}
        >
          {items}
        </UI.virtual_list>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("source_range", %{value: range}, assigns),
      do: {:noreply, %{assigns | range: range}}

    def handle_event("source_selected", %{value: selected}, assigns) do
      index =
        if selected == "target" do
          assigns.target_index
        else
          selected |> String.replace_prefix("item-", "") |> String.to_integer() |> Kernel.-(1)
        end

      {:noreply,
       %{
         assigns
         | selected: selected,
           selected_index: index,
           reveal: selected,
           reveal_index: index
       }}
    end

    @impl GPUI.View
    def handle_info({:list_height, height}, assigns),
      do: {:noreply, %{assigns | height: height}}

    def handle_info({:move_target, index}, assigns) do
      {:noreply,
       %{
         assigns
         | target_index: index,
           selected: "target",
           selected_index: index,
           reveal: "target",
           reveal_index: index
       }}
    end

    defp source_item(index, target_index) do
      id = if index == target_index, do: "target", else: "item-#{index + 1}"
      assigns = %{id: id}

      ~GPUI"""
      <UI.virtual_list_item id={assigns.id}>
        <div class="flex items-center h-[40px] px-3">
          <text class="text-white">{assigns.id}</text>
        </div>
      </UI.virtual_list_item>
      """
    end
  end

  defmodule SourceListApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Source List E2E" do
           size(420, 420)

           root(SourceListView,
             total_count: 100_000,
             range: %{first: 0, last: 32},
             selected: "target",
             selected_index: 99_999,
             reveal: "target",
             reveal_index: 99_999,
             target_index: 99_999,
             height: 400
           )
         end
       ]}
    end
  end

  defmodule ListApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Virtual List E2E" do
           size(420, 420)

           root(ListView,
             items: Enum.map(1..2_000, &"item-#{&1}"),
             selected: nil,
             reveal: nil,
             reveal_strategy: "nearest"
           )
         end
       ]}
    end
  end

  test "desktop wheel input changes a distant source-backed range", %{desktop: desktop} do
    runtime = start_runtime!(desktop, app: SourceListApp, poll_interval: 10)

    native_window_id = Desktop.window!(desktop, "GPUI Source List E2E")
    Desktop.await_frame!(desktop, runtime, 1, native_window_id)

    assert %{first: first, last: 100_000} = current_or_await_distant_range(runtime)
    assert first > 99_900

    assert {:ok, generation} = GPUI.Runtime.frame_token(runtime, 1)
    Desktop.scroll!(desktop, native_window_id, at: {120, 200}, delta: {0, 720})
    assert :ok = GPUI.Runtime.request_frame(runtime)
    Desktop.await_frame_after!(runtime, 1, generation)

    scrolled = await_source_range(runtime, &(&1.first < first and &1.last < 100_000))
    assert scrolled.first < first
    assert scrolled.last < 100_000
    assert Process.alive?(runtime)
  end

  test "desktop renders a full-snapshot virtual list and remains responsive", %{desktop: desktop} do
    runtime =
      start_runtime!(desktop,
        app: ListApp,
        poll_interval: 10,
        display_opts: [theme: :dark]
      )

    native_window_id = Desktop.window!(desktop, "GPUI Virtual List E2E")
    Desktop.await_frame!(desktop, runtime, 1, native_window_id)
    Desktop.capture_fixture!(desktop, native_window_id, "virtual-list")

    assert %{windows: [%{root: %{assigns: %{selected: nil}}}]} = GPUI.Runtime.snapshot(runtime)
    assert Process.alive?(runtime)
  end

  defp current_or_await_distant_range(runtime) do
    range = runtime |> GPUI.Runtime.snapshot() |> hd_window_assigns() |> Map.fetch!(:range)
    if range.last > 99_900, do: range, else: await_distant_range(runtime)
  end

  defp hd_window_assigns(snapshot),
    do: snapshot.windows |> hd() |> get_in([:root, :assigns])

  defp await_distant_range(runtime),
    do: await_source_range(runtime, &(&1.last > 99_900))

  defp await_source_range(runtime, predicate) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find_value(events, fn
               %{type: :range, event: "source_range", value: range} ->
                 if predicate.(range), do: range

               _event ->
                 nil
             end) do
          nil -> await_source_range(runtime, predicate)
          range -> range
        end
    after
      5_000 -> flunk("source-backed list did not emit the expected range")
    end
  end
end
