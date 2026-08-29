defmodule GPUI.Codegen.Native.Vanilla.ComponentDefinitions do
  @moduledoc false
  use RustQ.Meta
  require GPUI.Codegen.Native.ComponentDefinitionMacros
  GPUI.Codegen.Native.ComponentDefinitionMacros.define_components(:vanilla)
end

defmodule GPUI.Codegen.Native.Vanilla.SchemaTypes do
  @moduledoc false
  use RustQ.Meta
  require GPUI.Codegen.Native.SchemaTypeMacros
  GPUI.Codegen.Native.SchemaTypeMacros.define_schema_types(:vanilla)
end

defmodule GPUI.Codegen.Native.Vanilla.Dispatch do
  @moduledoc false
  use RustQ.Meta, callable_modules: [GPUI.Codegen.Native.Vanilla.ComponentDefinitions]
  require GPUI.Codegen.Native.DispatchDefinitions
  GPUI.Codegen.Native.DispatchDefinitions.define_dispatch(:vanilla)
end

defmodule GPUI.Codegen.Native.Vanilla.Registry do
  @moduledoc false
  use RustQ.Meta,
    rust_sources: ["apps/gpui_native/native/gpui/src/element/component_registry.rs"]

  require GPUI.Codegen.Native.RegistryDefinitions
  GPUI.Codegen.Native.RegistryDefinitions.define_registry(:vanilla)
end

defmodule GPUI.Codegen.Native.Vanilla.RendererDispatch do
  @moduledoc false
  use RustQ.Meta
  require GPUI.Codegen.Native.RendererDispatchDefinitions
  GPUI.Codegen.Native.RendererDispatchDefinitions.define_renderer_dispatch(:vanilla)
end
