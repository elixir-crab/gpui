defmodule Features.RichTranscript.View do
  use GPUI.View

  alias GPUI.Text.{Position, Range, RichRun}
  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col w-full h-full bg-slate-950 text-white">
      <div class="flex items-center justify-between px-5 py-3 bg-slate-900 border-b border-slate-800">
        <div class="flex flex-col">
          <text class="font-semibold">Neutral rich transcript</text>
          <text class="text-xs text-slate-400">Elixir owns content and runs; native owns shaping, selection, and measurement</text>
        </div>
        <div class="flex gap-2">
          <button phx-click="prepend" class="px-3 py-1 bg-slate-800 rounded">Older history</button>
          <button phx-click="stream" class="px-3 py-1 bg-slate-800 rounded">Stream tail</button>
          <button phx-click="append" class="px-3 py-1 bg-blue-600 rounded">Append</button>
        </div>
      </div>

      <UI.virtual_collection
        id="transcript"
        label="Conversation transcript"
        alignment="bottom"
        follow="tail"
        follow_request={assigns.follow_request}
        overdraw={320}
        phx-range="visible-range"
        class="grow min-h-0 px-6 py-4"
      >
        {Enum.map(assigns.messages, &message/1)}
      </UI.virtual_collection>

      <div class="flex items-center justify-between px-5 py-2 bg-slate-900 border-t border-slate-800">
        <text class="text-xs text-slate-400">{assigns.visible}</text>
        <text class="text-xs text-slate-400">{assigns.status}</text>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("visible-range", %{value: range}, assigns),
    do: {:noreply, %{assigns | visible: "visible #{range.first}–#{range.last}"}}

  def handle_event("open-link", %{type: :link, value: link}, assigns),
    do: {:noreply, %{assigns | status: "Activated #{link}"}}

  def handle_event("append", _event, assigns) do
    number = next_number(assigns.messages)
    {:noreply, %{assigns | messages: assigns.messages ++ [message_data(number)]}}
  end

  def handle_event("stream", _event, assigns) do
    id = List.last(assigns.messages).id

    messages =
      Enum.map(assigns.messages, fn
        %{id: ^id} = message ->
          %{
            message
            | body: message.body <> "\nA streamed paragraph changed this item's measured height.",
              revision: message.revision + 1
          }

        message ->
          message
      end)

    {:noreply, %{assigns | messages: messages}}
  end

  def handle_event("prepend", _event, assigns) do
    first = hd(assigns.messages).number
    older = Enum.map((first - 3)..(first - 1), &message_data/1)
    {:noreply, %{assigns | messages: older ++ assigns.messages}}
  end

  defp next_number(messages), do: List.last(messages).number + 1

  def message_data(number) do
    body =
      if rem(number, 3) == 0 do
        "Message #{number} has a longer body that wraps naturally. Native shaping determines its height while the collection retains the scroll anchor.\nOpen details"
      else
        "Message #{number} demonstrates neutral rich text.\nOpen details"
      end

    %{id: "message-#{number}", number: number, body: body, revision: 0}
  end

  defp message(message) do
    details = "Open details"
    {details_start, _length} = :binary.match(message.body, details)
    {line, column} = byte_position(message.body, details_start)

    runs = [
      RichRun.new(Range.new(Position.new(0, 0), Position.new(0, 9)),
        font_weight: :semibold,
        color: 0xF8FAFC
      ),
      RichRun.new(
        Range.new(
          Position.new(line, column),
          Position.new(line, column + String.length(details))
        ),
        color: 0x60A5FA,
        underline: 0x60A5FA,
        link: "message://#{message.id}"
      )
    ]

    assigns = Map.put(message, :runs, runs)

    ~GPUI"""
    <UI.virtual_item id={assigns.id} revision={assigns.revision}>
      <div class="mb-3 p-4 bg-slate-900 border border-slate-800 rounded-lg">
        <UI.rich_text
          id={"rich-#{assigns.id}"}
          label={"Message #{assigns.number}"}
          text={assigns.body}
          runs={assigns.runs}
          phx-link="open-link"
          class="w-full text-sm leading-6 text-slate-300"
        />
      </div>
    </UI.virtual_item>
    """
  end

  defp byte_position(text, byte_offset) do
    prefix = binary_part(text, 0, byte_offset)
    lines = String.split(prefix, "\n", trim: false)
    {length(lines) - 1, lines |> List.last() |> utf16_length()}
  end

  defp utf16_length(text) do
    text
    |> :unicode.characters_to_binary(:utf8, {:utf16, :little})
    |> byte_size()
    |> Kernel.div(2)
  end
end

defmodule Features.RichTranscript.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    messages = Enum.map(1..18, &Features.RichTranscript.View.message_data/1)

    {:ok,
     [
       window "Rich Transcript" do
         size(760, 720)

         root(Features.RichTranscript.View,
           messages: messages,
           follow_request: 0,
           visible: "range pending",
           status: "Select and copy text, or activate a link"
         )
       end
     ]}
  end
end
