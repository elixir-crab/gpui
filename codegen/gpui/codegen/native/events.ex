defmodule GPUI.Codegen.Native.Events do
  @moduledoc false

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.PatternBuilder, as: P
  alias RustQ.Rust.AST.TypeBuilder, as: T
  alias RustQ.Rust.Identifier

  @spec items() :: [AST.item()]
  def items do
    kinds =
      GPUI.Schema.components()
      |> Enum.flat_map(&Keyword.keys(&1.events))
      |> Enum.uniq()
      |> Enum.reject(&(&1 == :click))

    [input_kind(kinds), input_kind_impl(kinds)]
  end

  defp input_kind(kinds) do
    %AST.Enum{
      name: :InputKind,
      vis: :crate,
      derive: [:Clone, :Copy, :Debug],
      attrs: [A.attr(:allow, [:dead_code])],
      variants: Enum.map(kinds, &%AST.EnumVariant{name: variant(&1)})
    }
  end

  defp input_kind_impl(kinds) do
    atom_function = %AST.Function{
      name: :atom,
      args: [A.receiver()],
      returns: T.path(:Atom),
      body: [
        A.return_stmt(
          A.match_expr(
            :self,
            Enum.map(kinds, fn kind ->
              %AST.Arm{
                pattern: P.path([:Self, variant(kind)]),
                body: [A.return_stmt(A.path_call([:atoms, kind]))]
              }
            end)
          )
        )
      ]
    }

    A.impl(:InputKind, items: [atom_function])
  end

  defp variant(:keydown), do: :KeyDown
  defp variant(:keyup), do: :KeyUp

  defp variant(kind),
    do: kind |> Atom.to_string() |> Macro.camelize() |> Identifier.atom!()
end
