defmodule GPUI.Native.RichTranscriptE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule TranscriptView do
    use GPUI.View

    alias GPUI.Text.{Position, Range, RichRun}
    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[520px] h-[460px] bg-slate-950">
        <UI.virtual_collection
          id="rich-transcript"
          label="Rich transcript"
          alignment="bottom"
          follow="tail"
          follow_request={assigns.follow_request}
          overdraw={160}
          phx-range="visible-range"
          class="grow min-h-0 p-3"
        >
          {Enum.map(assigns.messages, &message/1)}
        </UI.virtual_collection>
        <UI.input
          id="clipboard-probe"
          label="Clipboard probe"
          value={assigns.clipboard}
          phx-change="clipboard-changed"
          class="m-3"
        />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("visible-range", %{value: range}, assigns),
      do: {:noreply, %{assigns | range: range}}

    def handle_event("open-link", %{type: :link, value: link}, assigns),
      do: {:noreply, %{assigns | link: link}}

    def handle_event("clipboard-changed", %{value: clipboard}, assigns),
      do: {:noreply, %{assigns | clipboard: clipboard}}

    @impl GPUI.View
    def handle_info(:stream, assigns) do
      last_id = List.last(assigns.messages).id

      messages =
        Enum.map(assigns.messages, fn
          %{id: ^last_id} = message ->
            %{message | text: message.text <> " streamed content", revision: message.revision + 1}

          message ->
            message
        end)

      {:noreply, %{assigns | messages: messages}}
    end

    def handle_info(:append, assigns) do
      number = length(assigns.messages) + 1
      {:noreply, %{assigns | messages: assigns.messages ++ [message_data(number)]}}
    end

    def handle_info(:prepend, assigns) do
      older = Enum.map(-2..0, &message_data/1)
      {:noreply, %{assigns | messages: older ++ assigns.messages}}
    end

    def handle_info(:follow, assigns),
      do: {:noreply, %{assigns | follow_request: assigns.follow_request + 1}}

    def message_data(number) do
      text = "Message #{number}: selectable rich content\nOpen details"
      %{id: "message-#{number}", number: number, text: text, revision: 0}
    end

    defp message(message) do
      detail_line = 1

      runs = [
        RichRun.new(Range.new(Position.new(0, 0), Position.new(0, 9)),
          font_weight: :bold,
          color: 0xF8FAFC
        ),
        RichRun.new(Range.new(Position.new(detail_line, 0), Position.new(detail_line, 12)),
          color: 0x60A5FA,
          underline: 0x60A5FA,
          link: "message://#{message.id}"
        )
      ]

      assigns = Map.put(message, :runs, runs)

      ~GPUI"""
      <UI.virtual_item id={assigns.id} revision={assigns.revision}>
        <div class="mb-2 p-3 bg-slate-900 rounded">
          <UI.rich_text
            id={"rich-#{assigns.id}"}
            label={"Message #{assigns.number}"}
            text={assigns.text}
            runs={assigns.runs}
            phx-link="open-link"
            class="w-full leading-6 text-slate-300"
          />
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
         window "GPUI Rich Transcript E2E" do
           size(520, 460)

           root(TranscriptView,
             messages: Enum.map(1..20, &TranscriptView.message_data/1),
             follow_request: 0,
             range: %{first: 0, last: 0},
             clipboard: "",
             link: nil
           )
         end
       ]}
    end
  end

  test "composes selectable rich text with variable tail growth and history" do
    {:ok, runtime} = GPUI.Runtime.start_link(app: TranscriptApp, poll_interval: 10)
    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    native_window_id = Desktop.window_id!("GPUI Rich Transcript E2E")
    Desktop.await_frame!(runtime, 1, native_window_id)
    assert %{last: 20} = await_range(runtime, &(&1.last == 20))

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, :stream)
    Desktop.await_frame!(runtime, 1, native_window_id)
    assert %{messages: messages} = assigns(runtime)
    assert List.last(messages).revision == 1

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, :append)
    Desktop.await_frame!(runtime, 1, native_window_id)
    assert %{last: 21} = await_range(runtime, &(&1.last == 21))

    Desktop.command!(["mousemove", "--window", native_window_id, "250", "180"])
    Desktop.command!(["click", "--repeat", "10", "4"])
    Desktop.await_frame!(runtime, 1, native_window_id)
    detached = await_range(runtime, &(&1.last < 21))

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, :prepend)
    Desktop.await_frame!(runtime, 1, native_window_id)
    assert %{range: after_prepend} = assigns(runtime)
    assert after_prepend.last < 24
    assert after_prepend.first in (detached.first - 3)..(detached.first + 3)

    assert {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, 1, :follow)
    Desktop.await_frame!(runtime, 1, native_window_id)
    assert %{last: 24} = await_range(runtime, &(&1.last == 24))
    assert Process.alive?(runtime)
  end

  defp await_range(runtime, predicate, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    receive_range(runtime, predicate, deadline)
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
      remaining -> flunk("rich transcript did not emit the expected visible range")
    end
  end

  defp assigns(runtime),
    do:
      runtime
      |> GPUI.Runtime.snapshot()
      |> Map.fetch!(:windows)
      |> hd()
      |> get_in([:root, :assigns])
end
