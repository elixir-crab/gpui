defmodule GPUI.Codegen.Native.Vanilla.RendererDispatch do
  @moduledoc "Defines renderer dispatch for the vanilla native host."
  use RustQ.Meta
  require GPUI.Codegen.Native.RendererDispatch.Definitions
  GPUI.Codegen.Native.RendererDispatch.Definitions.define_renderer_dispatch(:vanilla)
end
