defmodule GPUI.Native.ComposerTranscriptE2ETest do
  use ExUnit.Case, async: false

  alias GPUI.Text.{Buffer, Edit, Position, Range, Selection, Transaction}
  alias GPUITest.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule ComposerView do
    use GPUI.View

    alias GPUI.Text.{Edit, Position, Range, Selection, Transaction}
    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[560px] h-[500px] bg-slate-950">
        <UI.virtual_collection
          id="composer-transcript"
          label="Composer transcript"
          alignment="bottom"
          follow="tail"
          follow_request={assigns.follow_request}
          phx-range="visible-range"
          class="grow min-h-0 p-3"
        >
          {Enum.map(assigns.messages, &message/1)}
        </UI.virtual_collection>
        <div
          id="composer-bounds"
          phx-bounds-change="composer-bounds"
          class="mx-3 mb-3 p-2 bg-slate-800 rounded"
        >
          <text_surface
            id="native-composer"
            buffer={assigns.buffer}
            focus_request={assigns.focus_request}
            soft_wrap={true}
            auto_grow={true}
            min_lines={2}
            max_lines={4}
            submit_policy="submit"
            phx-transaction="draft-transaction"
            phx-submit="submit-draft"
            class="w-full px-2 text-white"
          />
        </div>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("visible-range", %{value: range}, assigns),
      do: {:noreply, %{assigns | range: range}}

    def handle_event("composer-bounds", %{value: bounds}, assigns),
      do: {:noreply, %{assigns | composer_heights: [bounds.height | assigns.composer_heights]}}

    def handle_event("draft-transaction", %{revision: revision}, assigns),
      do: {:noreply, %{assigns | revision: revision, transactions: assigns.transactions + 1}}

    def handle_event("submit-draft", %{value: value}, assigns) do
      {:ok, revision} = clear(assigns.buffer)
      number = Enum.count(assigns.messages) + 1

      {:noreply,
       %{
         assigns
         | messages: assigns.messages ++ [%{id: "message-#{number}", text: value}],
           revision: revision,
           submits: assigns.submits + 1,
           submitted: value,
           follow_request: assigns.follow_request + 1,
           focus_request: assigns.focus_request + 1
       }}
    end

    defp message(message) do
      ~GPUI"""
      <UI.virtual_item id={message.id}>
        <div class="mb-2 p-3 bg-slate-900 rounded">
          <UI.rich_text
            id={"rich-#{message.id}"}
            label={"Transcript message #{message.id}"}
            text={message.text}
            runs={[]}
            class="text-slate-200"
          />
        </div>
      </UI.virtual_item>
      """
    end

    defp clear(buffer) do
      {:ok, snapshot} = GPUI.Text.Buffer.snapshot(buffer)
      start_position = Position.new(0, 0)
      end_position = end_position(snapshot.text)

      {:ok, %{revision: revision}} =
        GPUI.Text.Buffer.transact(buffer, %Transaction{
          id: "composer-clear-#{System.unique_integer([:positive])}",
          base_revision: snapshot.revision,
          edits: [Edit.new(Range.new(start_position, end_position), "")],
          selections: [Selection.caret("primary", start_position, primary: true)]
        })

      {:ok, revision}
    end

    defp end_position(text) do
      lines = String.split(text, "\n", trim: false)
      last = List.last(lines)
      utf16 = :unicode.characters_to_binary(last, :utf8, {:utf16, :little})
      Position.new(Enum.count(lines) - 1, Kernel.div(byte_size(utf16), 2))
    end
  end

  defmodule ComposerApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title, buffer: buffer}) do
      messages = Enum.map(1..12, &%{id: "message-#{&1}", text: "Transcript message #{&1}"})

      {:ok,
       [
         window title do
           size(560, 500)

           root(ComposerView,
             buffer: buffer,
             messages: messages,
             revision: 0,
             transactions: 0,
             submits: 0,
             submitted: nil,
             follow_request: 0,
             focus_request: 1,
             range: %{first: 0, last: 0},
             composer_heights: []
           )
         end
       ]}
    end
  end

  test "auto-grows a persistent draft and submits it into the transcript" do
    {:ok, buffer} = Buffer.new("")
    title = "GPUI Composer Transcript E2E #{System.unique_integer([:positive])}"

    {:ok, runtime} =
      GPUI.Runtime.start_link(app: ComposerApp, args: %{title: title, buffer: buffer})

    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    window_id = Desktop.window_id!(title)

    Desktop.eventually(fn ->
      assert %{composer_heights: [initial | _], range: %{last: 12}} = assigns(runtime)
      assert initial > 0
    end)

    initial_height = assigns(runtime).composer_heights |> List.last()
    Desktop.click!(window_id, 280, 445)

    draft =
      "A long native draft wraps across several visual rows while the persistent text surface " <>
        "grows until its declared maximum and then keeps editing with internal scrolling."

    Desktop.type!(window_id, draft)

    Desktop.eventually(fn ->
      assert {:ok, %{text: ^draft}} = Buffer.snapshot(buffer)
      assert %{transactions: transactions, composer_heights: heights} = assigns(runtime)
      assert transactions > 0
      assert Enum.max(heights) > initial_height
    end)

    Desktop.key!(window_id, "shift+Return")

    Desktop.eventually(fn ->
      assert {:ok, %{text: text}} = Buffer.snapshot(buffer)
      assert text == draft <> "\n"
      assert assigns(runtime).submits == 0
    end)

    Desktop.type!(window_id, "second line")
    expected = draft <> "\nsecond line"
    Desktop.key!(window_id, "Return")

    Desktop.eventually(fn ->
      assert %{submits: 1, submitted: ^expected, messages: messages, range: %{last: 13}} =
               assigns(runtime)

      assert List.last(messages).text == expected
      assert {:ok, %{text: ""}} = Buffer.snapshot(buffer)
    end)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
