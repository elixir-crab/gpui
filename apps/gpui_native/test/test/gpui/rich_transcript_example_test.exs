GPUITest.Examples.load!(:rich_transcript)

defmodule GPUI.RichTranscriptExampleTest do
  use GPUI.Test, async: true

  @moduletag :native

  alias GPUI.Text.{Edit, Position, Range, Selection, Transaction}

  test "composes variable collection items with neutral rich text runs" do
    runtime = start_runtime!(Features.RichTranscript.App)

    assert %{messages: messages, status: status, draft_buffer: draft_buffer} = assigns(runtime)
    assert Enum.count(messages) == 18
    assert status =~ "Select and copy"
    assert {:ok, %{text: ""}} = GPUI.Text.Buffer.snapshot(draft_buffer)

    assert %{type: :ui_virtual_collection, attrs: %{alignment: "bottom", follow: "tail"}} =
             runtime |> tree() |> find!(id: "transcript")

    assert %{type: :text_surface, attrs: composer} =
             runtime |> tree() |> find!(id: "transcript-composer")

    assert %{
             :"phx-submit" => "submit-draft",
             auto_grow: true,
             min_lines: 2,
             max_lines: 6,
             submit_policy: "submit"
           } = Map.new(composer)

    rich = runtime |> tree() |> all(type: :ui_rich_text)
    assert Enum.count(rich) == 18

    assert Enum.all?(rich, fn %{attrs: %{runs: runs, text: text}} ->
             text != "" and
               Enum.all?(runs, fn run ->
                 is_map(run) and match?(%{range: %{start: %{}, end: %{}}}, run)
               end)
           end)
  end

  test "appends, streams height revisions, prepends history, and handles links" do
    runtime = start_runtime!(Features.RichTranscript.App)

    click(runtime, "append")
    assert %{messages: messages} = assigns(runtime)
    assert List.last(messages).number == 19

    click(runtime, "stream")
    assert %{messages: streamed} = assigns(runtime)
    assert List.last(streamed).revision == 1
    assert List.last(streamed).body =~ "streamed paragraph"

    click(runtime, "prepend")
    assert %{messages: prepended} = assigns(runtime)
    assert hd(prepended).number == -2
    assert Enum.count(prepended) == 22

    {:ok, _event, _snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :link,
        window_id: 1,
        event: "open-link",
        value: "message://message-19"
      })

    assert %{status: "Activated message://message-19"} = assigns(runtime)
  end

  test "submits the persistent draft, clears it, appends a message, and requests tail follow" do
    runtime = start_runtime!(Features.RichTranscript.App)
    %{draft_buffer: buffer, follow_request: initial_follow} = assigns(runtime)

    assert {:ok, %{revision: draft_revision}} = replace_text(buffer, "A composed message")
    assert {:ok, _snapshot} = GPUI.Runtime.refresh(runtime)

    {:ok, _event, _snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :submit,
        window_id: 1,
        event: "submit-draft",
        value: "A composed message"
      })

    assert %{
             messages: messages,
             draft_revision: revision,
             draft_status: "Submitted message 19",
             follow_request: follow_request,
             composer_focus_request: 2
           } = assigns(runtime)

    assert List.last(messages).body == "A composed message\nOpen details"
    assert follow_request == initial_follow + 1
    assert revision > draft_revision
    assert {:ok, %{text: ""}} = GPUI.Text.Buffer.snapshot(buffer)
  end

  defp replace_text(buffer, text) do
    {:ok, snapshot} = GPUI.Text.Buffer.snapshot(buffer)
    start_position = Position.new(0, 0)
    end_position = end_position(snapshot.text)

    GPUI.Text.Buffer.transact(buffer, %Transaction{
      id: "test-draft-#{System.unique_integer([:positive])}",
      base_revision: snapshot.revision,
      edits: [Edit.new(Range.new(start_position, end_position), text)],
      selections: [Selection.caret("primary", end_position(text), primary: true)]
    })
  end

  defp end_position(text) do
    lines = String.split(text, "\n", trim: false)
    last = List.last(lines)
    utf16 = :unicode.characters_to_binary(last, :utf8, {:utf16, :little})
    Position.new(Enum.count(lines) - 1, Kernel.div(byte_size(utf16), 2))
  end
end
