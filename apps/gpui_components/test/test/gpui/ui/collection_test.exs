defmodule GPUI.UI.CollectionTest do
  use ExUnit.Case, async: true

  alias GPUI.UI.Collection
  alias GPUI.UI.Collection.{Selection, Source}

  test "composes source-backed collection options" do
    items = [%GPUI.Element{type: :ui_virtual_list_item, attrs: [id: "record-40"]}]
    source = Source.new(100, 40, items)
    selected = Selection.new("record-40", 40)

    assert %{
             id: "records",
             total_count: 100,
             offset: 40,
             children: ^items,
             selected: "record-40",
             selected_index: 40,
             reveal: "record-40",
             reveal_index: 40
           } =
             %{id: "records"}
             |> Collection.source(source)
             |> Collection.selected(selected)
             |> Collection.reveal(selected)
  end

  test "source windows cannot exceed their logical collection" do
    assert_raise ArgumentError, ~r/must fit within total_count/, fn ->
      Source.new(1, 1, [:item])
    end
  end
end
