defmodule GPUI.Codegen.Native.Vanilla.Dispatch do
  @moduledoc "Defines vanilla-host element and component decoder dispatch."
  use RustQ.Meta, callable_modules: [GPUI.Codegen.Native.Vanilla.Definitions]
  require GPUI.Codegen.Native.Dispatch.Definitions
  GPUI.Codegen.Native.Dispatch.Definitions.define_dispatch(:vanilla)
end
