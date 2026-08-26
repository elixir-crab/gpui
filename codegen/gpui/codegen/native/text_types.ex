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

  @type text_edit :: %{
          required(:range) => R.path(:TextRange),
          required(:text) => String.t()
        }

  @type text_transaction :: %{
          required(:id) => String.t(),
          required(:base_revision) => R.u64(),
          required(:origin) => String.t(),
          required(:edits) => R.vec(R.path(:TextEdit)),
          required(:selections) => R.vec(R.path(:TextSelection))
        }

  @type text_snapshot :: %{
          required(:revision) => R.u64(),
          required(:text) => String.t(),
          required(:selections) => R.vec(R.path(:TextSelection)),
          required(:can_undo) => boolean(),
          required(:can_redo) => boolean()
        }

  @type transaction_result :: %{
          required(:revision) => R.u64(),
          required(:duplicate) => boolean(),
          required(:selections) => R.vec(R.path(:TextSelection))
        }

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    [
      :text_position,
      :text_range,
      :text_selection,
      :text_edit,
      :text_transaction,
      :text_snapshot,
      :transaction_result
    ]
    |> then(
      &MetaAST.struct_type_items(__MODULE__, &1,
        derive: [:Clone, :Debug, :PartialEq, :Eq, :NifMap],
        vis: :crate,
        field_vis: :crate,
        attrs: []
      )
    )
    |> Enum.map(fn struct ->
      %{struct | attrs: [A.attr(:allow, [:dead_code]) | struct.attrs]}
    end)
  end
end
