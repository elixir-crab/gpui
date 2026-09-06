defmodule GPUI.Codegen.Native.Accessibility.Definitions do
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
