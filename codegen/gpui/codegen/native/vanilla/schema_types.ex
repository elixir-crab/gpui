defmodule GPUI.Codegen.Native.Vanilla.SchemaTypes do
  @moduledoc "Defines vanilla-host schema types from neutral declarations."
  use RustQ.Meta
  require GPUI.Codegen.Native.SchemaType.Macros
  GPUI.Codegen.Native.SchemaType.Macros.define_schema_types(:vanilla)
end
