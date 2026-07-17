defmodule GPUI.Native.VirtualListE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e

  defmodule ListView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="w-[420px] h-[420px] bg-slate-900">
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

  test "virtualizes large collections and supports pointer, keyboard, and reveal" do
    {:ok, runtime} = GPUI.Runtime.start_link(app: ListApp, poll_interval: 10)
    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    native_window_id = Desktop.window_id!("GPUI Virtual List E2E")
    Desktop.await_frame!(runtime, 1, native_window_id)

    Desktop.click!(native_window_id, 120, 20)

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{
                      events: [%{event: "item_selected", value: "item-1"}]
                    }}

    Desktop.key!(native_window_id, "Down")

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{
                      events: [%{event: "item_selected", value: "item-3"}]
                    }}

    assert {:ok, generation} = GPUI.Runtime.frame_token(runtime, 1)
    Desktop.command!(["mousemove", "--window", native_window_id, "120", "200"])
    Desktop.command!(["click", "--repeat", "12", "5"])
    assert :ok = GPUI.Runtime.request_frame(runtime)
    Desktop.await_frame_after!(runtime, 1, generation)
    Desktop.click!(native_window_id, 120, 200)

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{
                      events: [%{event: "item_selected", value: wheel_selected}]
                    }}

    assert wheel_selected not in ~w(item-1 item-2 item-3)

    {_event, snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :change,
        window_id: 1,
        event: "item_selected",
        value: "item-2000"
      })

    assert %{windows: [%{root: %{assigns: %{selected: "item-2000"}}}]} = snapshot
    Desktop.await_frame!(runtime, 1, native_window_id)

    assert {:ok, %{windows: [%{root: %{assigns: %{selected: "item-2000"}}}]}} =
             GPUI.Runtime.send_view(
               runtime,
               1,
               {:replace_items, Enum.map(2_000..1//-1, &"item-#{&1}")}
             )

    Desktop.await_frame!(runtime, 1, native_window_id)
    Desktop.command!(["windowsize", native_window_id, "500", "300"])
    Desktop.await_frame!(runtime, 1, native_window_id)

    assert {:ok, %{windows: [%{root: %{assigns: %{selected: nil}}}]}} =
             GPUI.Runtime.send_view(
               runtime,
               1,
               {:replace_items, Enum.map(1..1_000, &"item-#{&1}")}
             )

    Desktop.await_frame!(runtime, 1, native_window_id)
    assert Process.alive?(runtime)
  end
end
