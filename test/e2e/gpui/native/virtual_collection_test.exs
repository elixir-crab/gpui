defmodule GPUI.Native.VirtualCollectionE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule TranscriptView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="w-[420px] h-[420px] p-3 bg-slate-950">
        <UI.virtual_collection
          id="transcript"
          label="Conversation transcript"
          alignment="bottom"
          follow="tail"
          follow_request={assigns.follow_request}
          reveal={assigns.reveal}
          reveal_request={assigns.reveal_request}
          reveal_strategy="top"
          overdraw={120}
          phx-range="visible-range"
          class="h-[396px] bg-slate-900"
        >
          {Enum.map(assigns.messages, &message/1)}
        </UI.virtual_collection>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("visible-range", %{value: range}, assigns) do
      {:noreply, %{assigns | range: range, range_events: assigns.range_events + 1}}
    end

    @impl GPUI.View
    def handle_info({:append, count}, assigns) do
      next = length(assigns.messages) + 1
      appended = Enum.map(next..(next + count - 1), &new_message/1)
      {:noreply, %{assigns | messages: assigns.messages ++ appended}}
    end

    def handle_info({:grow, id}, assigns) do
      messages =
        Enum.map(assigns.messages, fn
          %{id: ^id} = message -> %{message | lines: 8, revision: message.revision + 1}
          message -> message
        end)

      {:noreply, %{assigns | messages: messages}}
    end

    def handle_info(:follow_tail, assigns),
      do: {:noreply, %{assigns | follow_request: assigns.follow_request + 1}}

    def handle_info({:reveal, id}, assigns),
      do: {:noreply, %{assigns | reveal: id, reveal_request: assigns.reveal_request + 1}}

    def new_message(number) do
      %{id: "message-#{number}", number: number, lines: rem(number, 3) + 1, revision: 0}
    end

    defp message(message) do
      assigns = message

      ~GPUI"""
      <UI.virtual_item id={assigns.id} revision={assigns.revision}>
        <div
          class="px-3 py-2 border-b border-slate-700 bg-slate-900"
          style={[height: {:px, 20 + assigns.lines * 22}]}
        >
          <text class="text-white">{assigns.id}: {assigns.lines} lines</text>
        </div>
      </UI.virtual_item>
      """
    end
  end

  defmodule TranscriptApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Variable Collection E2E" do
           size(420, 420)

           root(TranscriptView,
             messages: Enum.map(1..30, &TranscriptView.new_message/1),
             follow_request: 0,
             reveal: nil,
             reveal_request: 0,
             range: %{first: 0, last: 0},
             range_events: 0
           )
         end
       ]}
    end
  end

  test "measures heterogeneous items, follows the tail, detaches, and reveals" do
    {:ok, runtime} = GPUI.Runtime.start_link(app: TranscriptApp, poll_interval: 10)
    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    native_window_id = Desktop.window_id!("GPUI Variable Collection E2E")
    Desktop.await_frame!(runtime, 1, native_window_id)

    initial = await_range(runtime, &(&1.last == 30))
    assert initial.first > 0

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, {:append, 3})
    Desktop.await_frame!(runtime, 1, native_window_id)
    following = await_range(runtime, &(&1.last == 33))
    assert following.first >= initial.first

    Desktop.repeat_click!(native_window_id, 200, 180, 12)
    Desktop.await_frame!(runtime, 1, native_window_id)
    detached = await_range(runtime, &(&1.last < 33))
    flush_updates(runtime)

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, {:append, 2})
    Desktop.await_frame!(runtime, 1, native_window_id)
    refute_tail_range(runtime, 35, 250)

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, :follow_tail)
    Desktop.await_frame!(runtime, 1, native_window_id)
    assert %{last: 35} = await_range(runtime, &(&1.last == 35))

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, {:grow, "message-35"})
    Desktop.await_frame!(runtime, 1, native_window_id)
    assert Process.alive?(runtime)

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, {:reveal, "message-5"})
    Desktop.await_frame!(runtime, 1, native_window_id)
    revealed = await_range(runtime, &(&1.first <= 4 and &1.last > 4))
    assert revealed.first <= 4
    assert detached.last < 33
    assert Process.alive?(runtime)
  end

  defp await_range(runtime, predicate, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    receive_range(runtime, predicate, deadline)
  end

  defp refute_tail_range(runtime, last, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    refute_tail_range_until(runtime, last, deadline)
  end

  defp refute_tail_range_until(runtime, last, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        refute Enum.any?(events, &match?(%{type: :range, value: %{last: ^last}}, &1))
        refute_tail_range_until(runtime, last, deadline)
    after
      remaining -> :ok
    end
  end

  defp flush_updates(runtime) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{}} -> flush_updates(runtime)
    after
      0 -> :ok
    end
  end

  defp receive_range(runtime, predicate, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find_value(events, fn
               %{type: :range, event: "visible-range", value: range} ->
                 if predicate.(range), do: range

               _event ->
                 nil
             end) do
          nil -> receive_range(runtime, predicate, deadline)
          range -> range
        end
    after
      remaining -> flunk("variable collection did not emit the expected visible range")
    end
  end
end
