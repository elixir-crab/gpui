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

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    Enum.map(MetaAST.functions(__MODULE__), fn
      %{name: :from_core_range} = function ->
        %{function | attrs: [A.attr(:cfg, feature: "components") | function.attrs]}

      function -> function
    end)
  end
end
