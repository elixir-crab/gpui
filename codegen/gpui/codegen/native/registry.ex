defmodule GPUI.Codegen.Native.Registry do
  @moduledoc "Emits the generated native component registry type and implementation items."

  use RustQ.Meta

  alias GPUI.Codegen.Native.Registry.Definitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require Definitions
  Definitions.define_registry(:gpui_component)

  @spec items() :: [AST.item()]
  def items do
    [
      type_item!(:ComponentKind, derive: [:Clone, :Copy, :Debug, :Eq, :Hash, :PartialEq]),
      type_item!(:StatefulComponent,
        attrs: [A.allow_attr(A.path([:clippy, :large_enum_variant]))]
      ),
      impl_item!()
    ]
  end

  defp impl_item!, do: MetaAST.impl!(__MODULE__, :ComponentRegistry)

  defp type_item!(name, opts) do
    item = MetaAST.enum_type_item!(__MODULE__, name)

    %{
      item
      | attrs: Keyword.get(opts, :attrs, []),
        derive: Keyword.get(opts, :derive, []),
        vis: nil
    }
  end
end
