defmodule GPUI.Codegen.Native.ResourceDefinitions do
  @moduledoc false

  defmacro define_resources do
    declarations =
      GPUI.Schema.resource_specs()
      |> Enum.flat_map(fn resource ->
        [resource_type_declaration(resource), resource_decoder_declaration(resource)]
      end)

    quote do
      (unquote_splicing(declarations))
    end
  end

  defp resource_type_declaration(resource) do
    type_name = type_name(resource)
    fields = resource.fields |> Enum.map(&resource_type_field/1) |> then(&{:%{}, [], &1})

    quote do
      @type unquote(type_name)() :: unquote(fields)
    end
  end

  defp resource_type_field({name, {:field, _source, type}}),
    do: {required(name), resource_field_type(type)}

  defp resource_type_field({name, type}), do: {required(name), resource_field_type(type)}

  defp resource_field_type(:u32), do: quote(do: R.u32())
  defp resource_field_type(type) when type in [:string, :atom], do: quote(do: String.t())
  defp resource_field_type(:binary), do: quote(do: binary())

  defp resource_field_type({:option, type}),
    do: quote(do: R.option(unquote(resource_field_type(type))))

  defp resource_field_type({:default, :atom_string, _default}), do: quote(do: String.t())

  defp resource_decoder_declaration(resource) do
    decoder = decoder_name(resource.name)
    struct = resource_struct_alias(resource.name)

    statements =
      Enum.flat_map(resource.fields, fn {name, type} ->
        decoder_statements(name, field_source(name, type), type)
      end)

    fields = Enum.map(resource.fields, fn {name, _type} -> {name, Macro.var(name, nil)} end)

    quote do
      @spec unquote(decoder)(term()) ::
              R.nif_result(R.path(unquote(resource_struct_name(resource.name))))
      defrust unquote(decoder)(term) do
        unquote_splicing(statements)
        {:ok, struct_literal(unquote(struct), unquote(fields))}
      end
    end
  end

  defp decoder_statements(name, source, {:field, _source, type}),
    do: decoder_statements(name, source, type)

  defp decoder_statements(name, source, :u32) do
    value = Macro.var(name, nil)

    [
      quote do
        unquote(value) = decode_as!(term.map_get(unquote(atom_call(source))), R.u32())
      end
    ]
  end

  defp decoder_statements(name, source, :string) do
    value = Macro.var(name, nil)

    [
      quote do
        unquote(value) = decode_as!(term.map_get(unquote(atom_call(source))), String.t())
      end
    ]
  end

  defp decoder_statements(name, source, :atom) do
    value = Macro.var(name, nil)
    term_value = Macro.var(String.to_atom("#{name}_term"), nil)

    [
      quote do
        unquote(term_value) = unwrap!(term.map_get(unquote(atom_call(source))))
      end,
      quote do
        unquote(value) = unwrap!(unquote(term_value).atom_to_string())
      end
    ]
  end

  defp decoder_statements(name, source, :binary) do
    value = Macro.var(name, nil)

    [
      quote do
        unquote(value) =
          decode_as!(term.map_get(unquote(atom_call(source))), R.path(:Binary))
          |> then(fn binary -> binary.as_slice().to_vec() end)
      end
    ]
  end

  defp decoder_statements(name, source, {:option, :u32}) do
    value = Macro.var(name, nil)

    [
      quote do
        unquote(value) =
          case term.map_get(unquote(atom_call(source))) do
            {:ok, field_value} -> decode_as(field_value, R.u32()).ok()
            {:error, _reason} -> nil
          end
      end
    ]
  end

  defp decoder_statements(name, source, {:default, :atom_string, default}) do
    value = Macro.var(name, nil)
    term_value = Macro.var(String.to_atom("#{name}_term"), nil)

    [
      quote do
        unquote(term_value) = unwrap!(term.map_get(unquote(atom_call(source))))
      end,
      quote do
        unquote(value) =
          case unquote(term_value).atom_to_string() do
            {:ok, decoded} -> decoded
            {:error, _reason} -> unquote(default).to_string()
          end
      end
    ]
  end

  defp field_source(_name, {:field, source, _type}), do: source
  defp field_source(name, _type), do: name

  defp atom_call(:type), do: quote(do: Atoms.type_atom())
  defp atom_call(name), do: {{:., [], [{:__aliases__, [], [:Atoms]}, name]}, [], []}

  defp required(name), do: {:required, [], [name]}

  @doc false
  def type_name(%{name: name}), do: String.to_atom("#{name}_data")

  defp resource_struct_name(name),
    do: name |> Atom.to_string() |> Macro.camelize() |> Kernel.<>("Data") |> String.to_atom()

  defp resource_struct_alias(name), do: {:__aliases__, [], [resource_struct_name(name)]}

  defp decoder_name(:resource_ref), do: :decode_resource_ref_data
  defp decoder_name(name), do: String.to_atom("decode_#{name}_resource")
end

defmodule GPUI.Codegen.Native.Resources do
  @moduledoc false

  use RustQ.Meta

  alias GPUI.Codegen.Native.ResourceDefinitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require ResourceDefinitions
  ResourceDefinitions.define_resources()

  @spec items() :: [AST.item()]
  def items do
    type_names = Enum.map(GPUI.Schema.resource_specs(), &ResourceDefinitions.type_name/1)

    structs =
      MetaAST.struct_type_items(
        __MODULE__,
        type_names,
        derive: [:Clone, :Debug, :Default],
        attrs: [A.attr(:cfg, feature: "real-gpui")],
        vis: :crate,
        field_vis: :crate
      )

    functions =
      Enum.map(MetaAST.functions(__MODULE__), fn function ->
        %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}
      end)

    structs ++ functions
  end
end
