defmodule GPUI.Codegen.Native.RendererDispatch do
  @moduledoc "Emits schema-derived dispatch from decoded element nodes to native renderers."

  use RustQ.Meta

  alias GPUI.Codegen.Native.RendererDispatch.Definitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require Definitions
  Definitions.define_renderer_dispatch(:gpui_component)

  @spec item() :: AST.Function.t()
  def item do
    function = MetaAST.function!(__MODULE__, :render_generated_component_node)
    %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}
  end
end
