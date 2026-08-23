defmodule GPUI.Codegen.Native.TextTypes do
  @moduledoc "Defines RustQ-owned structural codecs for renderer-independent text values."

  use RustQ.Meta

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @type text_position :: %{
          required(:line) => R.u64(),
          required(:utf16_offset) => R.u64()
        }

  @type text_range :: %{
          required(:start) => R.path(:TextPosition),
          required(:end) => R.path(:TextPosition)
        }

  @type text_selection :: %{
          required(:id) => String.t(),
          required(:anchor) => R.path(:TextPosition),
          required(:head) => R.path(:TextPosition),
          required(:primary) => boolean()
        }

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    [:text_position, :text_range, :text_selection]
    |> then(&MetaAST.struct_type_items(__MODULE__, &1,
      derive: [:Clone, :Debug, :PartialEq, :Eq, :NifMap],
      vis: :crate,
      field_vis: :crate,
      attrs: []
    ))
    |> Enum.map(fn struct ->
      %{struct | attrs: [A.attr(:allow, [:dead_code]) | struct.attrs]}
    end)
  end
end
