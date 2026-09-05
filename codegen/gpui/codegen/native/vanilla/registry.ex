defmodule GPUI.Codegen.Native.Vanilla.Registry do
  @moduledoc "Defines the vanilla-host component registry implementation."
  use RustQ.Meta,
    rust_sources: ["apps/gpui_native/native/src/element/component_registry.rs"]

  require GPUI.Codegen.Native.Registry.Definitions
  GPUI.Codegen.Native.Registry.Definitions.define_registry(:vanilla)
end
