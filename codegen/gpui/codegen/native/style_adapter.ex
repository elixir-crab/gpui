defmodule GPUI.Codegen.Native.StyleAdapter do
  @moduledoc "Generates exhaustive conversion from native wire styles to gpui_core styles."

  alias RustQ.Rust.AST, as: AST
  alias RustQ.Rust.AST.Builder, as: A

  @spec items() :: [AST.item()]
  def items do
    assignments = Enum.map(GPUI.Schema.style_specs(), &assignment/1)

    function = %AST.Function{
      name: :style_to_core,
      args: [A.function_arg(:wire, A.type_path(:StyleAttrs))],
      returns: A.type_path([:gpui_core, :Style]),
      body:
        [
          A.let_mut(:style, A.path_call([:gpui_core, :Style, :default])),
          assignments,
          A.return_stmt(A.var(:style))
        ]
        |> List.flatten(),
      vis: :crate,
      attrs: [
        A.attr(:cfg, feature: "real-gpui"),
        A.allow_attr(:dead_code),
        A.allow_attr(A.path([:clippy, :field_reassign_with_default]))
      ]
    }

    [function]
  end

  defp assignment(spec) do
    wire = A.field(A.var(:wire), spec.field)
    core = A.field(A.var(:style), spec.field)
    value = convert(spec.type, wire)
    A.assign(core, value)
  end

  defp convert(type, value) when type in [:length, :position_length, :flex_basis] do
    A.method(value, :map, [A.path_value([:gpui_core, :style_wire, length_function(type)])])
  end

  defp convert(_type, value), do: value
  defp length_function(:length), do: :definite_length
  defp length_function(_type), do: :length
end
