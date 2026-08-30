defmodule GPUI.Components.NativeContractTest do
  use ExUnit.Case, async: true

  alias GPUI.Components.NativeContract

  test "derives inspectable capabilities from package-owned declarations" do
    capabilities = NativeContract.capabilities()

    assert capabilities.schema_version == 1
    assert capabilities.provider == GPUI.Components.Schema.Declarations
    assert :ui_button in capabilities.components
    assert :ui_input in capabilities.stateful_components
    assert %{name: :click, payload: :none} in capabilities.events
    assert %{name: :drag_move, payload: :transfer} in capabilities.events
  end

  test "accounts for every declared component event" do
    declared =
      GPUI.Components.Schema.Declarations.components()
      |> Enum.flat_map(&Keyword.keys(&1.events))
      |> Enum.uniq()

    contracted = NativeContract.events() |> Enum.map(& &1.name)

    assert MapSet.new(contracted) == MapSet.new(declared)
    assert length(contracted) == length(Enum.uniq(contracted))
  end
end
