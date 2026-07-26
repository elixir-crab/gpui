defmodule GPUI.Codegen.Native.StyleDefinitions do
  @moduledoc false

  defmacro define_style_data do
    specs = GPUI.Schema.style_specs()
    fields = specs |> Enum.map(&style_type_field/1) |> then(&{:%{}, [], &1})

    quote do
      @type style_attrs :: unquote(fields)

      @spec full_length() :: R.path({:gpui, :DefiniteLength})
      defrust full_length() do
        Gpui.relative(1.0)
      end

      @spec pixel_length(R.f32()) :: R.path({:gpui, :DefiniteLength})
      defrust pixel_length(value) do
        Gpui.px(value).into()
      end

      @spec default_style() :: style_attrs()
      defrust default_style() do
        StyleAttrs.default()
      end
    end
  end

  defp style_type_field(spec), do: {required(spec.field), style_field_type(spec.type)}

  defp style_field_type({:atom_eq, _expected}), do: quote(do: boolean())
  defp style_field_type(:atom_string), do: quote(do: R.option(String.t()))
  defp style_field_type(:rgb), do: quote(do: R.option(R.u32()))

  defp style_field_type(type) when type in [:number, :px, :radius],
    do: quote(do: R.option(R.f32()))

  defp style_field_type(:length),
    do: quote(do: R.option(R.path({:gpui, :DefiniteLength})))

  defp required(name), do: {:required, [], [name]}
end

defmodule GPUI.Codegen.Native.Style do
  @moduledoc false

  use RustQ.Meta

  alias GPUI.Codegen.Native.StyleDefinitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.PatternBuilder, as: P
  alias RustQ.Rust.AST.TypeBuilder, as: T
  alias RustQ.Type, as: R

  require StyleDefinitions

  defrustmod(Gpui, as: :gpui)
  defrustmod(StyleAttrs, as: :StyleAttrs)

  StyleDefinitions.define_style_data()

  @allow :unreachable_patterns
  @spec decode_style(term()) :: R.nif_result(style_attrs())
  defrust decode_style(term) do
    attrs = unwrap!(term.map_get(Atoms.attrs()))

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
  def items(style_specs) do
    [
      generated_style_struct(),
      rusty_items(),
      generated_apply_style_function(style_specs),
      generated_apply_render_style_function(style_specs)
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

  defp generated_apply_style_function(style_specs) do
    arms =
      Enum.map(style_specs, fn spec ->
        %AST.Arm{
          pattern: %AST.PatAtomGuard{name: spec.name, module: [:atoms]},
          body: [
            A.let(:value, style_decode_call(spec.type)),
            A.let(:valid, valid_style_value(spec.type)),
            A.assign(A.field(A.var(:attrs), spec.field), :value),
            A.return_stmt(:valid)
          ]
        }
      end) ++
        [%AST.Arm{pattern: P.wildcard(), body: [A.return_stmt(A.lit(false))]}]

    %AST.Function{
      name: :apply_generated_style_attr,
      vis: :crate,
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      args: [
        A.arg(:attrs, T.mut_ref(:StyleAttrs)),
        A.arg(:key, T.path(:Atom)),
        A.arg(:term, T.path(:Term))
      ],
      returns: T.path(:bool),
      body: [A.return_stmt(A.match_expr(A.var(:key), arms))]
    }
  end

  defp valid_style_value({:atom_eq, _expected}), do: A.var(:value)
  defp valid_style_value(_type), do: A.method(:value, :is_some)

  defp style_decode_call({:atom_eq, expected}),
    do: A.call(:atom_eq, [A.var(:term), A.lit(to_string(expected))])

  defp style_decode_call(:atom_string), do: A.call(:atom_string, [A.var(:term)])
  defp style_decode_call(:rgb), do: A.call(:rgb_value, [A.var(:term)])
  defp style_decode_call(:number), do: A.call(:number_value, [A.var(:term)])
  defp style_decode_call(:px), do: A.call(:px_value, [A.var(:term)])
  defp style_decode_call(:length), do: A.call(:length_value, [A.var(:term)])
  defp style_decode_call(:radius), do: A.call(:radius_value, [A.var(:term)])

  defp generated_apply_render_style_function(style_specs) do
    %AST.Function{
      name: :apply_generated_render_styles,
      vis: :crate,
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      args: [A.arg(:element, T.path([:gpui, :Div])), A.arg(:style, T.path(:StyleAttrs))],
      returns: T.path([:gpui, :Div]),
      body:
        [A.let_mut(:element, A.var(:element))] ++
          (style_specs
           |> Enum.reject(&is_nil(&1.render))
           |> Enum.map(&render_style_statement/1)) ++
          [A.return_stmt(A.var(:element))]
    }
  end

  defp render_style_statement(%{field: field, render: :flex_if_true}) do
    A.stmt(
      A.if_expr(
        A.field(A.var(:style), field),
        [A.assign(A.var(:element), A.method(A.var(:element), :flex))],
        []
      )
    )
  end

  defp render_style_statement(%{field: field, render: {:enum_methods, values}}) do
    arms =
      Enum.map(values, fn {value, method} ->
        %AST.Arm{
          pattern: P.some(P.lit(value)),
          body: [A.assign(A.var(:element), A.method(A.var(:element), method))]
        }
      end) ++ [%AST.Arm{pattern: P.wildcard(), body: []}]

    style_value = A.field(A.var(:style), field)
    A.stmt(A.match_expr(A.method(style_value, :as_deref), arms))
  end

  defp render_style_statement(%{field: field, render: {:enum_values, method, values}}) do
    arms =
      Enum.map(values, fn {value, path} ->
        %AST.Arm{
          pattern: P.some(P.lit(value)),
          body: [
            A.assign(A.var(:element), A.method(A.var(:element), method, [A.path(path)]))
          ]
        }
      end) ++ [%AST.Arm{pattern: P.wildcard(), body: []}]

    style_value = A.field(A.var(:style), field)
    A.stmt(A.match_expr(A.method(style_value, :as_deref), arms))
  end

  defp render_style_statement(%{field: field, render: {:option_method, method, unit}})
       when unit in [:rgb, :px, :length, :f32] do
    rendered_value =
      case unit do
        :f32 -> A.var(:value)
        :length -> A.var(:value)
        unit -> A.path_call([:gpui, unit], [A.var(:value)])
      end

    A.if_let(
      P.some(P.var(:value)),
      A.field(A.var(:style), field),
      [A.assign(A.var(:element), A.method(A.var(:element), method, [rendered_value]))]
    )
  end
end
