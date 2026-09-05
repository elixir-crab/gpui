defmodule GPUI.Codegen.Native.Style.Definitions do
  @moduledoc "Derives RustQ style data, decoding, and application logic from GPUI.Schema styles."

  defmacro define_style_data do
    specs = GPUI.Schema.style_specs()
    fields = specs |> Enum.map(&style_type_field/1) |> then(&{:%{}, [], &1})

    clauses = Enum.map(specs, &style_clause/1) ++ [{:->, [], [[Macro.var(:_, nil)], false]}]

    style_case = {:case, [], [Macro.var(:key, nil), [do: clauses]]}
    render_statements = specs |> Enum.reject(&is_nil(&1.render)) |> Enum.map(&render_statement/1)

    quote do
      @type style_attrs :: unquote(fields)

      @spec full_length() :: R.path({:gpui, :DefiniteLength})
      defrust full_length() do
        GPUI.relative(1.0)
      end

      @spec fraction_length(R.f32()) :: R.path({:gpui, :DefiniteLength})
      defrust fraction_length(value) do
        GPUI.relative(value)
      end

      @spec pixel_length(R.f32()) :: R.path({:gpui, :DefiniteLength})
      defrust pixel_length(value) do
        GPUI.px(value).into()
      end

      @spec auto_flex_basis() :: R.path({:gpui, :Length})
      defrust auto_flex_basis() do
        GPUI.Length.Auto
      end

      @spec default_style() :: style_attrs()
      defrust default_style() do
        StyleAttrs.default()
      end

      @spec apply_generated_style_attr(R.mut_ref(style_attrs()), atom(), term()) :: boolean()
      defrust apply_generated_style_attr(attrs, key, term) do
        unquote(style_case)
      end

      @allow :unreachable_patterns
      @allow RustQ.Clippy.lint(:single_match)
      @spec apply_generated_render_styles(R.path({:gpui, :Div}), style_attrs()) ::
              R.path({:gpui, :Div})
      defrust apply_generated_render_styles(element, style) do
        element = element
        unquote_splicing(render_statements)
        element
      end
    end
  end

  defp style_type_field(spec), do: {required(spec.field), style_field_type(spec.type)}

  defp style_field_type({:atom_eq, _expected}), do: quote(do: boolean())
  defp style_field_type(:atom_string), do: quote(do: R.option(String.t()))
  defp style_field_type(:color), do: quote(do: R.option(R.u32()))

  defp style_field_type(type) when type in [:number, :px, :radius],
    do: quote(do: R.option(R.f32()))

  defp style_field_type(:length),
    do: quote(do: R.option(R.path({:gpui, :DefiniteLength})))

  defp style_field_type(:position_length),
    do: quote(do: R.option(R.path({:gpui, :Length})))

  defp style_field_type(:flex_basis),
    do: quote(do: R.option(R.path({:gpui, :Length})))

  defp style_clause(spec) do
    value = Macro.var(:value, nil)
    attrs = Macro.var(:attrs, nil)
    field = {{:., [], [attrs, spec.field]}, [no_parens: true], []}
    decoded = style_decode_call(spec.type)
    valid = Macro.var(:valid, nil)

    {:->, [],
     [
       [spec.name],
       quote do
         unquote(value) = unquote(decoded)
         unquote(valid) = unquote(valid_style_value(spec.type, value))
         assign!(unquote(field), unquote(value))
         unquote(valid)
       end
     ]}
  end

  defp valid_style_value({:atom_eq, _expected}, value), do: value
  defp valid_style_value(_type, value), do: quote(do: unquote(value).is_some())

  defp style_decode_call({:atom_eq, expected}),
    do: quote(do: atom_eq(term, unquote(to_string(expected))))

  defp style_decode_call(:atom_string), do: quote(do: atom_string(term))
  defp style_decode_call(:color), do: quote(do: color_value(term))
  defp style_decode_call(:number), do: quote(do: number_value(term))
  defp style_decode_call(:px), do: quote(do: px_value(term))
  defp style_decode_call(:length), do: quote(do: length_value(term))
  defp style_decode_call(:position_length), do: quote(do: position_length_value(term))
  defp style_decode_call(:flex_basis), do: quote(do: flex_basis_value(term))
  defp style_decode_call(:radius), do: quote(do: radius_value(term))

  defp render_statement(%{field: field, render: :flex_if_true}) do
    style_field = field_access(:style, field)

    quote do
      if unquote(style_field) do
        assign!(element, element.flex())
      end
    end
  end

  defp render_statement(%{field: field, render: :truncate_if_true}) do
    style_field = field_access(:style, field)

    quote do
      if unquote(style_field) do
        assign!(element, element.truncate())
      end
    end
  end

  defp render_statement(%{field: field, render: {:enum_methods, values}}) do
    render_option_case(field, values, fn method ->
      quote(do: assign!(element, element.unquote(method)()))
    end)
  end

  defp render_statement(%{field: field, render: {:enum_values, method, values}}) do
    render_option_case(field, values, fn path ->
      value = rust_path(path)
      quote(do: assign!(element, element.unquote(method)(unquote(value))))
    end)
  end

  defp render_statement(%{field: field, render: {:option_method, method, unit}})
       when unit in [:color, :px, :length, :position_length, :flex_basis, :f32] do
    rendered_value =
      case unit do
        unit when unit in [:f32, :length, :position_length, :flex_basis] ->
          Macro.var(:value, nil)

        :color ->
          quote do
            GPUI.rgba(value)
          end

        unit ->
          {{:., [], [{:__aliases__, [], [:GPUI]}, unit]}, [], [Macro.var(:value, nil)]}
      end

    render_option_value_case(field, fn ->
      quote(do: assign!(element, element.unquote(method)(unquote(rendered_value))))
    end)
  end

  defp render_statement(%{field: field, render: {:option_methods, methods, unit}})
       when unit == :position_length do
    render_option_value_case(field, fn ->
      methods
      |> Enum.map(fn method -> quote(do: assign!(element, element.unquote(method)(value))) end)
      |> then(&{:__block__, [], &1})
    end)
  end

  defp render_option_value_case(field, render) do
    clauses = [
      {:->, [], [[{:some, Macro.var(:value, nil)}], render.()]},
      {:->, [], [[Macro.var(:_, nil)], :ok]}
    ]

    {:case, [], [field_access(:style, field), [do: clauses]]}
  end

  defp render_option_case(field, values, render) do
    clauses =
      Enum.map(values, fn
        {:some, binding} ->
          pattern = {:some, Macro.var(binding, nil)}
          {:->, [], [[pattern], render.(binding)]}

        {value, action} ->
          pattern = {:some, value}
          {:->, [], [[pattern], render.(action)]}
      end) ++ [{:->, [], [[Macro.var(:_, nil)], :ok]}]

    style_field = field_access(:style, field)
    {:case, [], [quote(do: unquote(style_field).as_deref()), [do: clauses]]}
  end

  defp field_access(receiver, field),
    do: {{:., [], [Macro.var(receiver, nil), field]}, [no_parens: true], []}

  defp rust_path([:gpui | rest]), do: {:__aliases__, [], [:GPUI | rest]}
  defp rust_path(path), do: {:__aliases__, [], path}

  defp required(name), do: {:required, [], [name]}
end

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
