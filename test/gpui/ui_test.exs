defmodule GPUI.UITest do
  use ExUnit.Case, async: true

  alias GPUI.Element
  alias GPUI.UI

  test "builds controlled virtual lists from stable uniform items" do
    first = UI.virtual_list_item(%{id: "first", children: ["First"]})
    second = UI.virtual_list_item(%{id: "second", disabled: true, children: ["Second"]})

    assert %Element{
             type: :ui_virtual_list,
             attrs: attrs,
             children: [^first, ^second]
           } =
             UI.virtual_list(%{
               id: "records",
               label: "Records",
               selected: "first",
               reveal: "first",
               item_height: 48,
               children: [first, second]
             })

    assert attrs[:selected] == "first"
    assert attrs[:reveal] == "first"
    assert attrs[:reveal_strategy] == "nearest"
    assert attrs[:item_height] == 48
  end

  test "validates virtual list structure and controlled IDs" do
    item = UI.virtual_list_item(%{id: "first"})

    assert_raise ArgumentError, ~r/non-empty string label/, fn ->
      UI.virtual_list(%{id: "records", children: [item]})
    end

    assert_raise ArgumentError, ~r/item IDs must be unique/, fn ->
      UI.virtual_list(%{id: "records", label: "Records", children: [item, item]})
    end

    assert_raise ArgumentError, ~r/selected must identify/, fn ->
      UI.virtual_list(%{
        id: "records",
        label: "Records",
        selected: "missing",
        children: [item]
      })
    end

    assert_raise ArgumentError, ~r/item_height must be greater than zero/, fn ->
      UI.virtual_list(%{id: "records", label: "Records", item_height: 0, children: [item]})
    end

    assert_raise ArgumentError, ~r/only accepts virtual_list_item/, fn ->
      UI.virtual_list(%{
        id: "records",
        label: "Records",
        children: [%Element{type: :div}]
      })
    end
  end
end
