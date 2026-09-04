defmodule GPUI.Native.RichTranscriptE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

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

  test "desktop renders a variable rich transcript", %{desktop: desktop} do
    runtime = start_runtime!(desktop, app: TranscriptApp, poll_interval: 10)
    window = Desktop.window!(desktop, "GPUI Rich Transcript E2E")
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{messages: messages} = root_assigns(runtime)
    assert Enum.count_until(messages, 21) == 20
    assert Process.alive?(runtime)
  end

  defp root_assigns(runtime),
    do:
      runtime
      |> GPUI.Runtime.snapshot()
      |> Map.fetch!(:windows)
      |> hd()
      |> get_in([:root, :assigns])
end
