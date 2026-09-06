defmodule GPUI.Codegen.Native.Resources do
  @moduledoc "Emits generated native resource data types and bounded decoders."

  use RustQ.Meta

  alias GPUI.Codegen.Native.Resource.Definitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require Definitions
  Definitions.define_resources()

  @spec items() :: [AST.item()]
  def items do
    type_names = Enum.map(GPUI.Schema.resource_specs(), &Definitions.type_name/1)

    structs =
      MetaAST.struct_type_items(
        __MODULE__,
        type_names,
        derive: [:Clone, :Debug, :Default],
        attrs: [A.attr(:cfg, feature: "real-gpui")],
        vis: :crate,
        field_vis: :crate
      )

    functions =
      Enum.map(MetaAST.functions(__MODULE__), fn function ->
        %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}
      end)

    structs ++ functions
  end
end
