defmodule GPUI.DebugTest do
  use ExUnit.Case, async: true

  test "formats and queries authoritative trees without native state" do
    tree = %{
      type: :viewport,
      attrs: %{},
      children: [
        %{
          type: :div,
          attrs: %{id: "shell"},
          children: [
            %{
              type: :ui_button,
              attrs: %{id: "save", label: "Save", disabled: true},
              children: []
            },
            %{type: :text, attrs: %{}, children: ["Hello"]}
          ]
        }
      ]
    }

    assert %{type: :ui_button} = GPUI.Debug.find(tree, id: "save")
    assert Enum.map(GPUI.Debug.path(tree, id: "save"), & &1.type) == [:viewport, :div, :ui_button]

    assert GPUI.Debug.format_tree(tree) ==
             "viewport\n  └─ div#shell\n    └─ ui_button#save \"Save\" [disabled]\n    └─ text \"Hello\"\n"
  end

  test "uses bounded inspection for snapshots, identities, and elements" do
    identity = GPUI.Application.Identity.new!(id: "dev.gpui.demo", name: "Demo")
    snapshot = %GPUI.Snapshot{windows: [%{}], resources: %{"image" => %{}}}
    element = %GPUI.Element{type: :ui_button, attrs: [id: "save", label: "Save"]}

    assert inspect(identity) == ~s(#GPUI.Application.Identity<id="dev.gpui.demo" name="Demo">)
    assert inspect(snapshot) == "#GPUI.Snapshot<windows=1 resources=1>"
    assert inspect(element) =~ ~s(#GPUI.Element<:ui_button#save label="Save")
  end
end
