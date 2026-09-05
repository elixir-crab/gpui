defmodule GPUI.Codegen.Native.SchemaTypes do
  @moduledoc "Emits the generated native schema enums used by decoding and renderer dispatch."

  use RustQ.Meta

  alias GPUI.Codegen.Native.SchemaType.Macros
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require Macros
  Macros.define_schema_types(:gpui_component)

  @spec component_kind_item() :: AST.Enum.t()
  def component_kind_item,
    do: type_item!(:GeneratedComponentKind, derive: [:Clone, :Copy, :Debug, :Eq, :PartialEq])

  @spec element_tag_item() :: AST.Enum.t()
  def element_tag_item,
    do: type_item!(:GeneratedElementTag, derive: [:Clone, :Copy, :Debug, :Eq, :PartialEq])

  @spec element_node_item() :: AST.Enum.t()
  def element_node_item do
    type_item!(:ElementNode,
      derive: [:Clone, :Debug],
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      vis: :crate
    )
  end

  defp type_item!(name, opts) do
    item = MetaAST.enum_type_item!(__MODULE__, name)

    %{
      item
      | derive: Keyword.fetch!(opts, :derive),
        attrs: Keyword.get(opts, :attrs, item.attrs),
        vis: Keyword.get(opts, :vis, :pub)
    }
  end
end
