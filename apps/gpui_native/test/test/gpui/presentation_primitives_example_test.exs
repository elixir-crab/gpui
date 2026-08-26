GPUITest.Examples.load!(:presentation_primitives)

defmodule GPUI.PresentationPrimitivesExampleTest do
  use GPUI.Test, async: true

  test "composes versioned presentation primitives without display-dependent topology" do
    runtime = start_runtime!(Features.PresentationPrimitives.App)

    assert %{type: :ui_frost} = runtime |> tree() |> find!(id: "summary-frost")
    assert %{type: :ui_edge_fade} = runtime |> tree() |> find!(id: "activity-fades")
    assert %{type: :ui_paint} = runtime |> tree() |> find!(id: "sparkline")

    payload = snapshot(runtime).windows |> hd() |> get_in([:root, :tree])
    assert extension_version(payload, "summary-frost") == 1
    assert extension_version(payload, "activity-fades") == 1
    assert extension_version(payload, "sparkline") == 1
  end

  defp extension_version(tree, id) do
    case tree do
      %{attrs: %{id: ^id, __extension_version__: version}} -> version
      %{children: children} -> Enum.find_value(children, &extension_version(&1, id))
      _other -> nil
    end
  end
end
