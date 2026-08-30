defmodule GPUI.Codegen.Native.ComponentNodes do
  @moduledoc "Generates Rust owner models for migrated conventional components."

  use RustQ.Meta

  alias RustQ.Meta.AST, as: MetaAST

  @type switch_node :: %{
          required(:id) => String.t(),
          required(:checked) => boolean(),
          required(:label) => String.t(),
          required(:size) => RustQ.Type.option(String.t()),
          required(:disabled) => boolean(),
          required(:loading) => boolean(),
          required(:change) => RustQ.Type.option(String.t())
        }

  @type slider_node :: %{
          required(:id) => String.t(),
          required(:label) => String.t(),
          required(:value) => RustQ.Type.f64(),
          required(:min) => RustQ.Type.f64(),
          required(:max) => RustQ.Type.f64(),
          required(:step) => RustQ.Type.f64(),
          required(:orientation) => RustQ.Type.option(String.t()),
          required(:scale) => RustQ.Type.option(String.t()),
          required(:disabled) => boolean(),
          required(:reverse) => boolean(),
          required(:change) => RustQ.Type.option(String.t()),
          required(:release) => RustQ.Type.option(String.t())
        }

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    MetaAST.struct_type_items(__MODULE__, [:switch_node, :slider_node],
      derive: [:Clone, :Debug, :PartialEq],
      vis: :pub,
      field_vis: :pub,
      attrs: []
    )
  end
end
