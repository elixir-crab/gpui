defmodule GPUI.Codegen.Native.TextConversions do
  @moduledoc "Converts text boundary values to and from native core values."

  use RustQ.Meta,
    rust_sources: ["apps/gpui/native/src/text.rs"]

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @spec to_core_position(R.path(:TextPosition)) :: Core.Position.t()
  defrustp to_core_position(value) do
    struct_literal(Core.Position, line: value.line, utf16_offset: value.utf16_offset)
  end

  @spec from_core_position(Core.Position.t()) :: R.path(:TextPosition)
  defrustp from_core_position(value) do
    struct_literal(TextPosition, line: value.line, utf16_offset: value.utf16_offset)
  end

  @spec to_core_range(R.path(:TextRange)) :: Core.Range.t()
  defrustp to_core_range(value) do
    struct_literal(Core.Range,
      start: to_core_position(value.start),
      end: to_core_position(value.end)
    )
  end

  @spec from_core_range(Core.Range.t()) :: R.path(:TextRange)
  defrustp from_core_range(value) do
    struct_literal(TextRange,
      start: from_core_position(value.start),
      end: from_core_position(value.end)
    )
  end

  @spec to_core_selection(R.path(:TextSelection)) :: Core.Selection.t()
  defrustp to_core_selection(value) do
    struct_literal(Core.Selection,
      id: value.id,
      anchor: to_core_position(value.anchor),
      head: to_core_position(value.head),
      primary: value.primary
    )
  end

  @spec from_core_selection(Core.Selection.t()) :: R.path(:TextSelection)
  defrustp from_core_selection(value) do
    struct_literal(TextSelection,
      id: value.id,
      anchor: from_core_position(value.anchor),
      head: from_core_position(value.head),
      primary: value.primary
    )
  end

  @spec to_core_transaction(R.path(:TextTransaction)) :: Core.Transaction.t()
  defrustp to_core_transaction(value) do
    struct_literal(Core.Transaction,
      id: value.id,
      base_revision: value.base_revision,
      origin: value.origin,
      edits:
        Enum.map(value.edits, fn edit ->
          struct_literal(Core.Edit, range: to_core_range(edit.range), text: edit.text)
        end),
      selections: Enum.map(value.selections, &to_core_selection/1)
    )
  end

  @spec from_core_transaction(Core.Transaction.t()) :: R.path(:TextTransaction)
  defrustp from_core_transaction(value) do
    struct_literal(TextTransaction,
      id: value.id,
      base_revision: value.base_revision,
      origin: value.origin,
      edits:
        Enum.map(value.edits, fn edit ->
          struct_literal(TextEdit, range: from_core_range(edit.range), text: edit.text)
        end),
      selections: Enum.map(value.selections, &from_core_selection/1)
    )
  end

  @spec from_core_snapshot(Core.Snapshot.t()) :: R.path(:TextSnapshot)
  defrustp from_core_snapshot(value) do
    struct_literal(TextSnapshot,
      revision: value.revision,
      text: value.text,
      selections: Enum.map(value.selections, &from_core_selection/1),
      can_undo: value.can_undo,
      can_redo: value.can_redo
    )
  end

  @spec from_core_result(Core.TransactionResult.t()) :: R.path(:TransactionResult)
  defrustp from_core_result(value) do
    struct_literal(TransactionResult,
      revision: value.revision,
      duplicate: value.duplicate,
      selections: Enum.map(value.selections, &from_core_selection/1)
    )
  end

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    Enum.map(MetaAST.functions(__MODULE__), fn
      %{name: name} = function when name in [:from_core_range, :from_core_transaction] ->
        %{function | attrs: [A.attr(:cfg, feature: "components") | function.attrs]}

      function ->
        function
    end)
  end
end
