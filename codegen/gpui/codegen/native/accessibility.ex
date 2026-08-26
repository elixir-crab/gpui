defmodule GPUI.Codegen.Native.AccessibilityDefinitions do
  @moduledoc "Builds RustQ accessibility types and conversion implementations from GPUI.Accessibility policy."

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro define_contracts do
    role_variants =
      Enum.map(GPUI.Accessibility.role_specs(), fn {name, _spec} -> {name, []} end)

    role_decode =
      decode_clauses(GPUI.Accessibility.role_specs(), :AccessibilityRole) ++
        [{:->, [], [[Macro.var(:_unknown, nil)], quote(do: {:error, badarg()})]}]

    accessibility_struct = {:__aliases__, [], [:AccessibilitySemantics]}

    quote do
      @type accessibility_role :: R.enum(unquote(role_variants))
      @type accessibility_checked :: R.enum(false: [], true: [], mixed: [])
      @type accessibility_orientation :: R.enum(horizontal: [], vertical: [])

      @type accessibility_semantics :: %{
              required(:role) => R.option(accessibility_role()),
              required(:label) => R.option(String.t()),
              required(:description) => R.option(String.t()),
              required(:value) => R.option(String.t()),
              required(:selected) => R.option(boolean()),
              required(:expanded) => R.option(boolean()),
              required(:checked) => R.option(accessibility_checked()),
              required(:orientation) => R.option(accessibility_orientation()),
              required(:disabled) => boolean()
            }

      @spec decode_accessibility_role(term()) :: R.nif_result(R.option(accessibility_role()))
      defrust decode_accessibility_role(term) do
        case component_string_attr(term, Atoms.accessibility_role()) do
          {:ok, {:some, value}} ->
            case value.as_str() do
              (unquote_splicing(role_decode))
            end

          {:ok, nil} ->
            {:ok, nil}

          {:error, reason} ->
            {:error, reason}
        end
      end

      @spec decode_accessibility_checked(term()) ::
              R.nif_result(R.option(accessibility_checked()))
      defrust decode_accessibility_checked(term) do
        case component_string_attr(term, Atoms.accessibility_checked()) do
          {:ok, {:some, value}} ->
            case value.as_str() do
              "false" -> {:ok, some(enum_variant(AccessibilityChecked, false))}
              "true" -> {:ok, some(enum_variant(AccessibilityChecked, true))}
              "mixed" -> {:ok, some(enum_variant(AccessibilityChecked, :mixed))}
              _unknown -> {:error, badarg()}
            end

          {:ok, nil} ->
            {:ok, nil}

          {:error, reason} ->
            {:error, reason}
        end
      end

      @spec decode_accessibility_orientation(term()) ::
              R.nif_result(R.option(accessibility_orientation()))
      defrust decode_accessibility_orientation(term) do
        case component_string_attr(term, Atoms.accessibility_orientation()) do
          {:ok, {:some, value}} ->
            case value.as_str() do
              "horizontal" -> {:ok, some(enum_variant(AccessibilityOrientation, :horizontal))}
              "vertical" -> {:ok, some(enum_variant(AccessibilityOrientation, :vertical))}
              _unknown -> {:error, badarg()}
            end

          {:ok, nil} ->
            {:ok, nil}

          {:error, reason} ->
            {:error, reason}
        end
      end

      @spec decode_accessibility(term()) :: R.nif_result(accessibility_semantics())
      defrust decode_accessibility(term) do
        {:ok,
         struct_literal(
           unquote(accessibility_struct),
           role: unwrap!(decode_accessibility_role(term)),
           label: non_empty_string_attr(term, Atoms.accessibility_label()),
           description: non_empty_string_attr(term, Atoms.accessibility_description()),
           value: non_empty_string_attr(term, Atoms.accessibility_value()),
           selected: unwrap!(component_bool_attr(term, Atoms.accessibility_selected())),
           expanded: unwrap!(component_bool_attr(term, Atoms.accessibility_expanded())),
           checked: unwrap!(decode_accessibility_checked(term)),
           orientation: unwrap!(decode_accessibility_orientation(term)),
           disabled:
             unwrap!(component_bool_attr(term, Atoms.accessibility_disabled())).unwrap_or(false)
         )}
      end
    end
  end

  defp decode_clauses(specs, enum) do
    enum = {:__aliases__, [], [enum]}

    Enum.map(specs, fn {name, _spec} ->
      {:->, [],
       [
         [Atom.to_string(name)],
         quote(do: {:ok, some(enum_variant(unquote(enum), unquote(name)))})
       ]}
    end)
  end
end

defmodule GPUI.Codegen.Native.Accessibility do
  @moduledoc "Emits the generated Rust accessibility contracts and AccessKit conversion items."

  use RustQ.Meta, rust_sources: ["apps/gpui_native/native/gpui/src/element/mod.rs"]

  alias GPUI.Codegen.Native.AccessibilityDefinitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require AccessibilityDefinitions
  AccessibilityDefinitions.define_contracts()

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
