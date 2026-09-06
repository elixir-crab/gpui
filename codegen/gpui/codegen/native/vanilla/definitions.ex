defmodule GPUI.Codegen.Native.Vanilla.Definitions do
  @moduledoc "Defines vanilla-host component metadata from neutral declarations."
  use RustQ.Meta
  require GPUI.Codegen.Native.Component.Macros
  GPUI.Codegen.Native.Component.Macros.define_components(:vanilla)
end
