defmodule GPUI.TreeTest do
  use ExUnit.Case, async: true

  test "queries struct and serialized trees through one traversal" do
    struct_tree = %GPUI.Element{
      type: :div,
      attrs: [id: "root"],
      children: [%GPUI.Element{type: :text, children: ["Hello"]}]
    }

    map_tree = GPUI.Element.to_payload(struct_tree)

    for tree <- [struct_tree, map_tree] do
      assert GPUI.Tree.find!(tree, id: "root").type == :div
      assert length(GPUI.Tree.all(tree, type: :text)) == 1
      assert Enum.map(GPUI.Tree.path(tree, type: :text), & &1.type) == [:div, :text]
    end
  end
end
