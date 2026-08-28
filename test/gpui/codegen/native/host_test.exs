defmodule GPUI.Codegen.Native.HostTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Host
  alias GPUI.Schema.Registry

  test "vanilla excludes and gpui-component includes conventional components" do
    vanilla = Host.vanilla()
    component_host = Host.gpui_component()

    refute :ui_button in Registry.native_tags(vanilla)
    refute :ui_split in Registry.native_tags(vanilla)

    assert :div in Registry.native_tags(vanilla)
    assert :ui_paint in Registry.native_tags(vanilla)
    assert :ui_button in Registry.native_tags(component_host)
    refute Enum.any?(Registry.stateful_components(vanilla), &(&1.kind == :button_component))
    assert length(component_host.components) > length(vanilla.components)
  end
end
