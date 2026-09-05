defmodule GPUI.Codegen.Native.Accessibility do
  @moduledoc "Emits the generated Rust accessibility contracts and AccessKit conversion items."

  use RustQ.Meta, rust_sources: ["apps/gpui_native/native/src/element/mod.rs"]

  alias GPUI.Codegen.Native.Accessibility.Definitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require Definitions
  Definitions.define_contracts()

  @spec items() :: [AST.item()]
  def items do
    type_items = MetaAST.generated_type_items(__MODULE__)

    enums =
      Enum.map([:AccessibilityRole, :AccessibilityChecked, :AccessibilityOrientation], fn name ->
        enum =
          Enum.find(type_items, &match?(%AST.Enum{name: ^name}, &1)) || raise "missing #{name}"

        %{
          enum
          | derive: [:Clone, :Copy, :Debug, :Eq, :PartialEq],
            vis: :crate,
            attrs: [A.attr(:allow, [:dead_code]) | enum.attrs]
        }
      end)

    semantics =
      MetaAST.struct_type_items(__MODULE__, [:accessibility_semantics],
        derive: [:Clone, :Debug, :Default],
        attrs: [A.attr(:allow, [:dead_code])],
        vis: :crate,
        field_vis: :crate
      )

    functions =
      Enum.map(MetaAST.functions(__MODULE__), fn function ->
        function =
          RustQ.Rust.AST.Walk.prewalk(function, fn
            %AST.StructLiteral{path: %AST.Path{parts: [:accessibility_semantics]}} = literal ->
              %{literal | path: A.path(:AccessibilitySemantics)}

            node ->
              node
          end)

        %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}
      end)

    generated_impls = generated_conversion_impls() ++ [generated_interaction_impl()]
    enums ++ semantics ++ functions ++ generated_impls
  end

  defp generated_conversion_impls do
    role_arms =
      Enum.map(GPUI.Accessibility.role_specs(), fn {name, %{gpui: gpui_role}} ->
        conversion_arm(:AccessibilityRole, name, [:gpui, :Role, gpui_role])
      end)

    [
      conversion_impl(:AccessibilityRole, :gpui_role, [:gpui, :Role], role_arms),
      conversion_impl(:AccessibilityChecked, :toggled, [:gpui, :Toggled], [
        conversion_arm(:AccessibilityChecked, false, [:gpui, :Toggled, :False]),
        conversion_arm(:AccessibilityChecked, true, [:gpui, :Toggled, :True]),
        conversion_arm(:AccessibilityChecked, :mixed, [:gpui, :Toggled, :Mixed])
      ]),
      conversion_impl(:AccessibilityOrientation, :gpui_orientation, [:gpui, :Orientation], [
        conversion_arm(
          :AccessibilityOrientation,
          :horizontal,
          [:gpui, :Orientation, :Horizontal]
        ),
        conversion_arm(:AccessibilityOrientation, :vertical, [:gpui, :Orientation, :Vertical])
      ])
    ]
  end

  defp generated_interaction_impl do
    arms =
      Enum.map(GPUI.Accessibility.role_specs(), fn {name, %{interaction: interaction}} ->
        %AST.Arm{
          pattern:
            RustQ.Rust.AST.PatternBuilder.path([
              :AccessibilityRole,
              rust_variant(name)
            ]),
          body: [A.return_stmt(interaction == :activate)]
        }
      end)

    function = %AST.Function{
      name: :is_activatable,
      args: [A.receiver()],
      returns: A.type_path(:bool),
      body: [A.return_stmt(A.match_expr(A.var(:self), arms))]
    }

    A.impl(A.type_path(:AccessibilityRole),
      items: [function],
      attrs: [A.attr(:allow, [:dead_code])]
    )
  end

  defp conversion_impl(target, function_name, return_type, arms) do
    function = %AST.Function{
      name: function_name,
      args: [A.receiver()],
      returns: A.type_path(return_type),
      body: [A.return_stmt(A.match_expr(A.var(:self), arms))]
    }

    A.impl(A.type_path(target),
      items: [function],
      attrs: [A.attr(:cfg, feature: "real-gpui")]
    )
  end

  defp conversion_arm(target, variant, value_path) do
    %AST.Arm{
      pattern: RustQ.Rust.AST.PatternBuilder.path([target, rust_variant(variant)]),
      body: [A.return_stmt(A.path_value(value_path))]
    }
  end

  defp rust_variant(value), do: value |> Atom.to_string() |> Macro.camelize() |> String.to_atom()
end
