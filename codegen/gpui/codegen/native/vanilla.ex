defmodule GPUI.Codegen.Native.Vanilla.Definitions do
  @moduledoc false
  use RustQ.Meta
  require GPUI.Codegen.Native.Component.Macros
  GPUI.Codegen.Native.Component.Macros.define_components(:vanilla)
end

defmodule GPUI.Codegen.Native.Vanilla.SchemaTypes do
  @moduledoc false
  use RustQ.Meta
  require GPUI.Codegen.Native.SchemaType.Macros
  GPUI.Codegen.Native.SchemaType.Macros.define_schema_types(:vanilla)
end

defmodule GPUI.Codegen.Native.Vanilla.Dispatch do
  @moduledoc false
  use RustQ.Meta, callable_modules: [GPUI.Codegen.Native.Vanilla.Definitions]
  require GPUI.Codegen.Native.Dispatch.Definitions
  GPUI.Codegen.Native.Dispatch.Definitions.define_dispatch(:vanilla)
end

defmodule GPUI.Codegen.Native.Vanilla.Registry do
  @moduledoc false
  use RustQ.Meta,
    rust_sources: ["apps/gpui_native/native/src/element/component_registry.rs"]

  require GPUI.Codegen.Native.Registry.Definitions
  GPUI.Codegen.Native.Registry.Definitions.define_registry(:vanilla)
end

defmodule GPUI.Codegen.Native.Vanilla.RendererDispatch do
  @moduledoc false
  use RustQ.Meta
  require GPUI.Codegen.Native.RendererDispatch.Definitions
  GPUI.Codegen.Native.RendererDispatch.Definitions.define_renderer_dispatch(:vanilla)
end
