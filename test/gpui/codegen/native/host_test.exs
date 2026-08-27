defmodule GPUI.Codegen.Native.HostTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Host
  alias GPUI.Schema.Registry

  test "vanilla excludes and gpui-component includes conventional components" do
    vanilla = Host.vanilla()
    component_host = Host.gpui_component()

    refute Enum.any?(
             Registry.native_tags(vanilla),
             &String.starts_with?(Atom.to_string(&1), "ui_")
           )

    assert :div in Registry.native_tags(vanilla)
    assert :ui_button in Registry.native_tags(component_host)
    assert length(component_host.components) > length(vanilla.components)
  end
end
