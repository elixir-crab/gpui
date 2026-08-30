defmodule GPUI.Codegen.Native.ComponentAdapters do
  @moduledoc "Generates move-based adapters from NIF wire nodes to component-owner nodes."

  alias RustQ.Rust.AST, as: AST
  alias RustQ.Rust.AST.Builder, as: A

  @migrated [
    switch: [:id, :checked, :label, :size, :disabled, :loading, :change],
    slider: [
      :id,
      :label,
      :value,
      :min,
      :max,
      :step,
      :orientation,
      :scale,
      :disabled,
      :reverse,
      :change,
      :release
    ]
  ]

  @spec items() :: [AST.item()]
  def items do
    Enum.map(@migrated, fn {name, fields} -> adapter(name, fields) end)
  end

  defp adapter(name, fields) do
    wire_type = type_name(name, "ComponentNode")
    owner_type = type_name(name, "Node")

    owner_fields =
      [style: A.call(:style_to_core, [A.field(A.var(:wire), :style)])] ++
        Enum.map(fields, &{&1, A.field(A.var(:wire), &1)})

    %AST.Function{
      name: String.to_atom("#{name}_to_owner"),
      args: [A.function_arg(:wire, A.type_path(wire_type))],
      returns: A.type_path([:gpui_components, owner_type]),
      body: [A.return_stmt(A.struct_expr([:gpui_components, owner_type], owner_fields))],
      vis: :crate,
      attrs: [A.attr(:cfg, feature: "components"), A.allow_attr(:dead_code)]
    }
  end

  defp type_name(name, suffix),
    do: name |> Atom.to_string() |> Macro.camelize() |> Kernel.<>(suffix) |> String.to_atom()
end
