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

    [event_value(), event_value_impl(), input_kind(kinds), input_kind_impl(kinds)]
  end

  defp event_value do
    %AST.Enum{
      name: :EventValue,
      vis: :crate,
      derive: [:Clone, :Debug],
      attrs: [A.attr(:allow, [:dead_code])],
      variants: [
        %AST.EnumVariant{name: :String, tuple: [T.path(:String)]},
        %AST.EnumVariant{name: :Strings, tuple: [T.vec(:String)]},
        %AST.EnumVariant{name: :Boolean, tuple: [T.path(:bool)]},
        %AST.EnumVariant{name: :Number, tuple: [T.path(:f64)]},
        %AST.EnumVariant{name: :Nil}
      ]
    }
  end

  defp event_value_impl do
    encode = %AST.Function{
      name: :encode,
      lifetimes: [:a],
      args: [A.receiver(), A.arg(:env, T.path(:Env, lifetimes: [:a]))],
      returns: T.path(:Term, lifetimes: [:a]),
      body: [
        A.return_stmt(
          A.match_expr(:self, [
            event_value_arm(:String),
            event_value_arm(:Strings),
            event_value_arm(:Boolean),
            event_value_arm(:Number),
            %AST.Arm{
              pattern: P.path([:Self, :Nil]),
              body: [A.return_stmt(A.method(A.path_call([:atoms, nil]), :encode, [:env]))]
            }
          ])
        )
      ]
    }

    A.impl(:EventValue, items: [encode])
  end

  defp event_value_arm(variant) do
    %AST.Arm{
      pattern: P.path_tuple([:Self, variant], [:value]),
      body: [A.return_stmt(A.method(:value, :encode, [:env]))]
    }
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
