defmodule GPUI.UITest do
  use ExUnit.Case, async: true

  alias GPUI.Element
  alias GPUI.UI

  test "builds progress, file picker, and clipboard controls" do
    assert %Element{type: :ui_progress, attrs: progress} =
             UI.progress(%{id: "upload", label: "Uploading", value: 25, max: 50})

    assert progress[:value] == 25
    assert progress[:max] == 50
    assert progress[:indeterminate] == false

    assert %Element{type: :ui_file_picker, attrs: picker} =
             UI.file_picker(%{:"phx-change" => "selected", id: "source", label: "Choose source"})

    assert picker[:max_bytes] == 25 * 1_024 * 1_024

    assert %Element{type: :ui_copy_button, attrs: copy} =
             UI.copy_button(%{:"phx-click" => "copied", id: "copy", label: "Copy", text: "value"})

    assert copy[:text] == "value"
  end

  test "validates progress, file picker, and clipboard values" do
    assert_raise ArgumentError, ~r/value must be between zero and max/, fn ->
      UI.progress(%{id: "upload", label: "Uploading", value: 101})
    end

    assert_raise ArgumentError, ~r/max_bytes must be between/, fn ->
      UI.file_picker(%{
        :"phx-change" => "selected",
        id: "source",
        label: "Choose",
        max_bytes: 1.5
      })
    end

    assert_raise ArgumentError, ~r/requires string text/, fn ->
      UI.copy_button(%{:"phx-click" => "copied", id: "copy", label: "Copy", text: :invalid})
    end
  end

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
