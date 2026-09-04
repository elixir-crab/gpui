defmodule GPUI.Text.TransactionTest do
  use ExUnit.Case, async: true

  alias GPUI.Text.{Edit, Position, Selection, Snapshot, Transaction}

  test "builds against a snapshot and reuses its selections by default" do
    position = Position.new(0, 0)
    selection = Selection.caret("primary", position, primary: true)

    snapshot = %Snapshot{
      revision: 7,
      text: "hello",
      selections: [selection],
      can_undo: false,
      can_redo: false
    }

    assert %Transaction{
             id: "insert",
             base_revision: 7,
             origin: :external,
             edits: [%Edit{text: "!"}],
             selections: [^selection]
           } =
             Transaction.new(snapshot,
               id: "insert",
               edits: [Edit.insert(Position.new(0, 5), "!")]
             )
  end

  test "selection constructor supports directed and collapsed selections" do
    anchor = Position.new(0, 1)
    head = Position.new(0, 3)

    assert %Selection{anchor: ^anchor, head: ^head, primary: true} =
             Selection.new("primary", anchor, head, primary: true)

    assert %Selection{anchor: ^anchor, head: ^anchor} = Selection.caret("caret", anchor)
  end

  test "rejects malformed transactions at construction time" do
    snapshot = %Snapshot{
      revision: 0,
      text: "",
      selections: [],
      can_undo: false,
      can_redo: false
    }

    assert_raise ArgumentError, ~r/id must be a non-empty string/, fn ->
      Transaction.new(snapshot, id: "")
    end
  end
end
