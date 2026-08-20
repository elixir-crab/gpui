defmodule GPUI.Text.BufferTest do
  use ExUnit.Case, async: true

  @moduletag :native

  alias GPUI.Text.{Buffer, Edit, Position, Range, Selection, Transaction}

  test "applies revisioned UTF-16 edits and snapshots native Rope state" do
    assert {:ok, buffer} = Buffer.new("a🎉b\r\n中文", revision: 7)

    transaction = %Transaction{
      id: "replace-emoji",
      base_revision: 7,
      origin: :external,
      edits: [
        Edit.new(Range.new(Position.new(0, 1), Position.new(0, 3)), "é")
      ],
      selections: [Selection.caret("primary", Position.new(0, 2), primary: true)]
    }

    assert {:ok, %{revision: 8, duplicate: false, selections: [selection]}} =
             Buffer.transact(buffer, transaction)

    assert selection.head == Position.new(0, 2)

    assert {:ok,
            %GPUI.Text.Snapshot{
              revision: 8,
              text: "aéb\r\n中文",
              can_undo: true,
              can_redo: false
            }} = Buffer.snapshot(buffer)
  end

  test "rejects stale, conflicting, invalid, and overlapping transactions" do
    assert {:ok, buffer} = Buffer.new("🎉abc")

    transaction = transaction("insert", 0, {0, 2}, {0, 2}, "x", {0, 3})
    assert {:ok, %{revision: 1, duplicate: false}} = Buffer.transact(buffer, transaction)
    assert {:ok, %{revision: 1, duplicate: true}} = Buffer.transact(buffer, transaction)

    assert {:error, :transaction_conflict} =
             Buffer.transact(buffer, %{transaction | edits: [edit(0, 2, 0, 2, "y")]})

    assert {:error, {:stale_revision, 1}} =
             Buffer.transact(buffer, transaction("stale", 0, {0, 0}, {0, 0}, "z", {0, 1}))

    assert {:error, :invalid_position} =
             Buffer.transact(buffer, transaction("surrogate", 1, {0, 1}, {0, 1}, "z", {0, 1}))

    overlapping = %Transaction{
      id: "overlap",
      base_revision: 1,
      edits: [edit(0, 2, 0, 3, "x"), edit(0, 2, 0, 4, "y")],
      selections: [Selection.caret("primary", Position.new(0, 2), primary: true)]
    }

    assert {:error, :overlapping_edits} = Buffer.transact(buffer, overlapping)
  end

  test "addresses CJK and combining code points in UTF-16 units" do
    assert {:ok, buffer} = Buffer.new("中e\u0301文")

    assert {:ok, %{revision: 1}} =
             Buffer.transact(
               buffer,
               transaction("combining", 0, {0, 2}, {0, 3}, "", {0, 2})
             )

    assert {:ok, %{text: "中e文"}} = Buffer.snapshot(buffer)
  end

  test "applies multiple edits against one base revision atomically" do
    assert {:ok, buffer} = Buffer.new("one two three")

    transaction = %Transaction{
      id: "multiple",
      base_revision: 0,
      edits: [edit(0, 0, 0, 3, "1"), edit(0, 8, 0, 13, "3")],
      selections: [Selection.caret("primary", Position.new(0, 1), primary: true)]
    }

    assert {:ok, %{revision: 1}} = Buffer.transact(buffer, transaction)
    assert {:ok, %{text: "1 two 3"}} = Buffer.snapshot(buffer)
  end

  test "undo and redo preserve monotonic revisions" do
    assert {:ok, buffer} = Buffer.new("ab")

    assert {:ok, %{revision: 1}} =
             Buffer.transact(buffer, transaction("insert", 0, {0, 1}, {0, 1}, "x", {0, 2}))

    assert {:ok, %{revision: 2, text: "ab", can_redo: true}} = Buffer.undo(buffer, 1)
    assert {:ok, %{revision: 3, text: "axb", can_undo: true}} = Buffer.redo(buffer, 2)
    assert {:error, {:stale_revision, 3}} = Buffer.undo(buffer, 2)
  end

  test "uses plural selections while the first implementation requires one primary selection" do
    assert {:error, :invalid_selection} = Buffer.new("", selections: [])

    assert {:error, :invalid_selection} =
             Buffer.new("",
               selections: [Selection.caret("secondary", Position.new(0, 0))]
             )

    assert {:error, :invalid_selection} =
             Buffer.new("",
               selections: [
                 Selection.caret("primary", Position.new(0, 0), primary: true),
                 Selection.caret("secondary", Position.new(0, 0))
               ]
             )
  end

  test "does not expose carriage returns as logical line content" do
    assert {:ok, buffer} = Buffer.new("a\r\nb")

    assert {:error, :invalid_position} =
             Buffer.transact(
               buffer,
               transaction("inside-crlf", 0, {0, 2}, {0, 2}, "x", {0, 1})
             )

    assert {:ok, %{revision: 1}} =
             Buffer.transact(
               buffer,
               transaction("next-line", 0, {1, 0}, {1, 0}, "x", {1, 1})
             )

    assert {:ok, %{text: "a\r\nxb"}} = Buffer.snapshot(buffer)
  end

  defp transaction(id, revision, start_position, end_position, text, caret_position) do
    {caret_line, caret_offset} = caret_position

    %Transaction{
      id: id,
      base_revision: revision,
      edits: [edit(start_position, end_position, text)],
      selections: [
        Selection.caret("primary", Position.new(caret_line, caret_offset), primary: true)
      ]
    }
  end

  defp edit(start_line, start_offset, end_line, end_offset, text),
    do: edit({start_line, start_offset}, {end_line, end_offset}, text)

  defp edit({start_line, start_offset}, {end_line, end_offset}, text) do
    Edit.new(
      Range.new(
        Position.new(start_line, start_offset),
        Position.new(end_line, end_offset)
      ),
      text
    )
  end
end
