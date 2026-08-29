defmodule GPUI.Codegen.Native.ComponentDefinitionMacros do
  @moduledoc "Expands GPUI component schema entries into RustQ node types and decoder declarations."

  defmacro define_components(host) do
    host = Macro.expand(host, __CALLER__)

    declarations =
      GPUI.Codegen.Native.Host.components(host)
      |> Enum.filter(&component_contract?/1)
      |> Enum.flat_map(fn component ->
        [component_type_declaration(component), component_decoder_declaration(component)]
      end)

    quote do
      (unquote_splicing(declarations))
    end
  end

  defp component_type_declaration(component) do
    fields =
      [style: quote(do: R.path(:StyleAttrs))] ++
        Enum.map(component.attrs, fn {name, type} -> {name, component_field_type(name, type)} end) ++
        if(component.children, do: [children: quote(do: R.vec(R.path(:ElementNode)))], else: []) ++
        Enum.map(component.events, fn {name, _attr} -> {name, quote(do: R.option(String.t()))} end)

    fields =
      fields |> Enum.map(fn {name, type} -> {required(name), type} end) |> then(&{:%{}, [], &1})

    type_name = component_type_name(component)

    quote do
      @type unquote(type_name)() :: unquote(fields)
    end
  end

  defp component_decoder_declaration(component) do
    decoder = decoder_name(component)
    type_name = component_type_name(component)
    struct = {:__aliases__, [], [component_node_name(component)]}

    fields =
      [style: quote(do: unwrap!(decode_style(term)))] ++
        Enum.map(component.attrs, fn {name, type} ->
          {name, component_decoder_expr(name, type)}
        end) ++
        if(component.children,
          do: [children: quote(do: unwrap!(decode_children(term)))],
          else: []
        ) ++
        Enum.map(component.events, fn {name, attr} ->
          {name, quote(do: unwrap!(component_string_attr(term, unquote(atom_call(attr)))))}
        end)

    version_check =
      case component.extension do
        %GPUI.Schema.Extension{id: id, version: version} ->
          quote do
            unwrap!(
              require_extension_version(term, unquote(Atom.to_string(id)), unquote(version))
            )
          end

        nil ->
          nil
      end

    body =
      if version_check do
        quote do
          unquote(version_check)
          {:ok, struct_literal(unquote(struct), unquote(fields))}
        end
      else
        quote do
          {:ok, struct_literal(unquote(struct), unquote(fields))}
        end
      end

    quote do
      @allow RustQ.Clippy.redundant_field_names()
      @allow RustQ.Clippy.lint(:useless_vec)
      @spec unquote(decoder)(term()) :: R.nif_result(unquote(type_name)())
      defrust(unquote(decoder)(term), do: unquote(body))
    end
  end

  defp component_field_type(:id, :string), do: quote(do: String.t())
  defp component_field_type(_name, :required_string), do: quote(do: String.t())
  defp component_field_type(_name, :string), do: quote(do: R.option(String.t()))
  defp component_field_type(_name, {:default, :string}), do: quote(do: String.t())

  defp component_field_type(_name, {:default, type, _value})
       when type in [:number, :positive_number, :unit_number, :edge_fade_size],
       do: quote(do: R.f64())

  defp component_field_type(_name, :non_negative_integer), do: quote(do: R.option(R.u64()))

  defp component_field_type(_name, {:default, type, _value})
       when type in [:non_negative_integer, :positive_integer],
       do: quote(do: R.u64())

  defp component_field_type(_name, :positive_integer), do: quote(do: R.option(R.u64()))

  defp component_field_type(_name, {:default, {:enum, _values}, _default}),
    do: quote(do: R.option(String.t()))

  defp component_field_type(_name, {:default, {:enum_list, _values}, _default}),
    do: quote(do: R.vec(String.t()))

  defp component_field_type(_name, :boolean), do: quote(do: boolean())
  defp component_field_type(_name, {:default, :boolean, _value}), do: quote(do: boolean())
  defp component_field_type(_name, :string_list), do: quote(do: R.vec(String.t()))
  defp component_field_type(_name, :number_pair), do: quote(do: R.vec(R.f64()))

  defp component_field_type(_name, {:default, :number_pair, _default}),
    do: quote(do: R.vec(R.f64()))

  defp component_field_type(_name, {:default, :paint_commands, _default}),
    do: quote(do: R.vec(R.path(:PaintCommand)))

  defp component_field_type(_name, {:enum, _values}), do: quote(do: R.option(String.t()))

  defp component_field_type(_name, :select_options),
    do: quote(do: R.vec(R.path(:SelectOptionNode)))

  defp component_field_type(_name, :radio_options), do: quote(do: R.vec(R.path(:RadioOptionNode)))

  defp component_field_type(_name, :paint_commands),
    do: quote(do: R.vec(R.path(:PaintCommand)))

  defp component_field_type(_name, :rich_text_runs),
    do: quote(do: R.vec(R.path(:RichTextRunNode)))

  defp component_decoder_expr(:id, :string), do: quote(do: unwrap!(component_id(term)))

  defp component_decoder_expr(name, :required_string),
    do: quote(do: unwrap!(component_required_string_attr(term, unquote(atom_call(name)))))

  defp component_decoder_expr(name, :string),
    do: quote(do: unwrap!(component_string_attr(term, unquote(atom_call(name)))))

  defp component_decoder_expr(name, {:default, :string}),
    do:
      quote(
        do: unwrap!(component_string_attr(term, unquote(atom_call(name)))).unwrap_or_default()
      )

  defp component_decoder_expr(name, {:default, type, default})
       when type in [:number, :positive_number, :unit_number, :edge_fade_size] do
    helper =
      if type in [:positive_number, :edge_fade_size],
        do: :component_positive_number_attr,
        else: :component_number_attr

    quote(
      do: unwrap!(unquote(helper)(term, unquote(atom_call(name)))).unwrap_or(unquote(default))
    )
  end

  defp component_decoder_expr(name, :non_negative_integer),
    do: quote(do: unwrap!(component_non_negative_integer_attr(term, unquote(atom_call(name)))))

  defp component_decoder_expr(name, {:default, type, default})
       when type in [:non_negative_integer, :positive_integer] do
    helper =
      if type == :positive_integer,
        do: :component_positive_integer_attr,
        else: :component_non_negative_integer_attr

    quote(
      do: unwrap!(unquote(helper)(term, unquote(atom_call(name)))).unwrap_or(unquote(default))
    )
  end

  defp component_decoder_expr(name, :positive_integer),
    do: quote(do: unwrap!(component_positive_integer_attr(term, unquote(atom_call(name)))))

  defp component_decoder_expr(name, :boolean),
    do: quote(do: unwrap!(component_bool_attr(term, unquote(atom_call(name)))).unwrap_or(false))

  defp component_decoder_expr(name, {:default, :boolean, default}),
    do:
      quote(
        do:
          unwrap!(component_bool_attr(term, unquote(atom_call(name)))).unwrap_or(unquote(default))
      )

  defp component_decoder_expr(name, :string_list),
    do: quote(do: unwrap!(component_string_list_attr(term, unquote(atom_call(name)))))

  defp component_decoder_expr(name, :number_pair),
    do: quote(do: unwrap!(component_number_pair_attr(term, unquote(atom_call(name)))))

  defp component_decoder_expr(name, {:default, :number_pair, default}),
    do:
      quote(
        do:
          unwrap!(component_optional_number_pair_attr(term, unquote(atom_call(name))))
          |> unwrap_or_else(fn -> unquote(default) end)
      )

  defp component_decoder_expr(_name, {:default, :paint_commands, _default}),
    do: quote(do: unwrap!(decode_paint_commands(term)))

  defp component_decoder_expr(name, {:enum, values}) do
    quote do
      unwrap!(component_enum_attr(term, unquote(atom_call(name)), ref(unquote(values))))
    end
  end

  defp component_decoder_expr(name, {:default, {:enum, values}, default}) do
    quote do
      case unwrap!(component_enum_attr(term, unquote(atom_call(name)), ref(unquote(values)))) do
        {:some, value} -> some(value)
        :none -> some(unquote(default).to_string())
      end
    end
  end

  defp component_decoder_expr(name, {:default, {:enum_list, values}, _default}) do
    quote do
      unwrap!(component_enum_list_attr(term, unquote(atom_call(name)), ref(unquote(values))))
    end
  end

  defp component_decoder_expr(_name, :select_options),
    do: quote(do: unwrap!(decode_select_options(term)))

  defp component_decoder_expr(_name, :radio_options),
    do: quote(do: unwrap!(decode_radio_options(term)))

  defp component_decoder_expr(_name, :rich_text_runs),
    do: quote(do: unwrap!(decode_rich_text_runs(term)))

  defp atom_call(name),
    do: {{:., [], [{:__aliases__, [], [:Atoms]}, rust_atom_name(name)]}, [], []}

  defp component_contract?(component),
    do: component.kind |> Atom.to_string() |> String.ends_with?("_component")

  defp component_type_name(component),
    do: component.kind |> Atom.to_string() |> Kernel.<>("_node") |> String.to_atom()

  defp component_node_name(component),
    do:
      component.kind
      |> Atom.to_string()
      |> Macro.camelize()
      |> Kernel.<>("Node")
      |> String.to_atom()

  defp decoder_name(component), do: String.to_atom("decode_generated_#{component.kind}")
  defp required(name), do: {:required, [], [name]}

  defp rust_atom_name(atom),
    do: atom |> Atom.to_string() |> String.replace(~r/[^a-zA-Z0-9_]/, "_") |> String.to_atom()
end

defmodule GPUI.Codegen.Native.ComponentDefinitions do
  @moduledoc "Emits generated Rust component node definitions and decoders."

  use RustQ.Meta

  alias GPUI.Codegen.Native.ComponentDefinitionMacros
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require ComponentDefinitionMacros
  ComponentDefinitionMacros.define_components(:gpui_component)

  @spec items() :: [AST.item()]
  def items do
    components =
      GPUI.Codegen.Native.Host.components(:gpui_component)
      |> Enum.filter(&String.ends_with?(Atom.to_string(&1.kind), "_component"))

    structs =
      __MODULE__
      |> MetaAST.struct_type_items(
        Enum.map(components, &String.to_atom("#{&1.kind}_node")),
        derive: [:Clone, :Debug],
        attrs: [A.attr(:cfg, feature: "real-gpui"), A.attr(:allow, [:dead_code])],
        vis: :crate,
        field_vis: :crate
      )
      |> Map.new(&{&1.name, &1})

    functions =
      __MODULE__
      |> MetaAST.functions()
      |> Map.new(fn function ->
        function =
          %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}

        {function.name, function}
      end)

    Enum.flat_map(components, fn component ->
      node =
        component.kind
        |> Atom.to_string()
        |> Macro.camelize()
        |> Kernel.<>("Node")
        |> String.to_atom()

      decoder = String.to_atom("decode_generated_#{component.kind}")
      [Map.fetch!(structs, node), Map.fetch!(functions, decoder)]
    end)
  end
end
