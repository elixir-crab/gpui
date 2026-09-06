defmodule GPUI.Codegen.Native.Style do
  @moduledoc "Emits generated native style contracts and schema-derived application dispatch."

  use RustQ.Meta

  alias GPUI.Codegen.Native.Style.Definitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  require Definitions

  defrustmod(GPUI, as: :gpui)
  defrustmod(StyleAttrs, as: :StyleAttrs)

  Definitions.define_style_data()

  @allow :unreachable_patterns
  @spec decode_style(term()) :: R.nif_result(style_attrs())
  defrust decode_style(term) do
    attrs = unwrap!(decode_element_attrs(term))

    case attrs.map_get(Atoms.style()) do
      {:ok, style} ->
        entries = decode_as!(style, R.vec({atom(), term()}))
        decoded = default_style()

        valid =
          for entry <- entries, reduce: true do
            valid ->
              {key, value} = entry
              apply_generated_style_attr(mut_ref(decoded), key, value) and valid
          end

        if valid do
          {:ok, decoded}
        else
          {:error, badarg()}
        end

      {:error, _missing} ->
        {:ok, default_style()}
    end
  end

  @spec items([GPUI.Schema.Style.t()]) :: [AST.item()]
  def items(_style_specs) do
    [
      generated_style_struct(),
      rusty_items()
    ]
    |> List.flatten()
  end

  defp rusty_items do
    Enum.map(MetaAST.functions(__MODULE__), fn ast ->
      %{ast | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | ast.attrs]}
    end)
  end

  defp generated_style_struct do
    [struct] =
      MetaAST.struct_type_items(
        __MODULE__,
        [:style_attrs],
        derive: [:Clone, :Debug, :Default],
        attrs: [A.attr(:cfg, feature: "real-gpui")],
        vis: :crate,
        field_vis: :crate
      )

    struct
  end
end
