GPUITest.Examples.load!(:rich_transcript)

defmodule GPUI.RichTranscriptExampleTest do
  use GPUI.Test, async: true

  alias GPUI.Text.RichRun

  test "composes variable collection items with neutral rich text runs" do
    runtime = start_gpui!(Features.RichTranscript.App)

    assert %{messages: messages, status: status} = assigns(runtime)
    assert Enum.count(messages) == 18
    assert status =~ "Select and copy"

    assert %{type: :ui_virtual_collection, attrs: %{alignment: "bottom", follow: "tail"}} =
             runtime |> tree() |> find!(id: "transcript")

    rich = runtime |> tree() |> all(type: :ui_rich_text)
    assert Enum.count(rich) == 18

    assert Enum.all?(rich, fn %{attrs: %{runs: runs, text: text}} ->
             text != "" and Enum.all?(runs, &match?(%RichRun{}, &1))
           end)
  end

  test "appends, streams height revisions, prepends history, and handles links" do
    runtime = start_gpui!(Features.RichTranscript.App)

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

    {_event, _snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :link,
        window_id: 1,
        event: "open-link",
        value: "message://message-19"
      })

    assert %{status: "Activated message://message-19"} = assigns(runtime)
  end
end
