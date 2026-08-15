defmodule GPUI.Codegen.Native.RegistryDefinitions do
  @moduledoc false

  defmacro define_registry do
    components = GPUI.Schema.stateful_components()

    component_kind_variants = Enum.map(components, &{registry_method(&1), []})

    stateful_component_variants =
      Enum.map(components, fn component ->
        {registry_method(component), [quote(do: R.path(unquote(registry_type(component))))]}
      end)

    functions = Enum.flat_map(components, &[getter(&1), inserter(&1)]) ++ [remover(:text_surface)]

    quote do
      @type component_kind :: R.enum(unquote(component_kind_variants))
      @type stateful_component :: R.enum(unquote(stateful_component_variants))

      defrustimpl ComponentRegistry, vis: :crate do
        (unquote_splicing(functions))
      end
    end
  end

  defp getter(component) do
    method = registry_method(component)
    name = String.to_atom("#{method}_mut")
    type = registry_type(component)

    quote do
      @spec unquote(name)(
              R.mut_ref(R.path(:ComponentRegistry)),
              R.str()
            ) :: R.option(R.mut_ref(R.path(unquote(type))))
      defrust unquote(name)(self, id) do
        key = ComponentKey.new(enum_variant(ComponentKind, unquote(method)), id)
        self.active.insert(key.clone())

        case self.entries.get_mut(ref(key)) do
          {:some, enum_variant(StatefulComponent, unquote(method), component)} -> some(component)
          _ -> nil
        end
      end
    end
  end

  defp inserter(component) do
    method = registry_method(component)
    name = String.to_atom("insert_#{method}")
    type = registry_type(component)

    quote do
      @spec unquote(name)(
              R.mut_ref(R.path(:ComponentRegistry)),
              R.str(),
              R.path(unquote(type))
            ) :: boolean()
      defrust unquote(name)(self, id, component) do
        key = ComponentKey.new(enum_variant(ComponentKind, unquote(method)), id)
        self.active.insert(key.clone())

        self.entries.insert(key, enum_variant(StatefulComponent, unquote(method), component)).is_none()
      end
    end
  end

  defp remover(method) do
    name = String.to_atom("remove_#{method}")

    quote do
      @spec unquote(name)(R.mut_ref(R.path(:ComponentRegistry)), R.str()) :: boolean()
      defrust unquote(name)(self, id) do
        key = ComponentKey.new(enum_variant(ComponentKind, unquote(method)), id)
        self.active.remove(ref(key))
        self.entries.remove(ref(key)).is_some()
      end
    end
  end

  defp registry_method(%{kind: :text_surface}), do: :text_surface

  defp registry_method(component) do
    component.kind
    |> Atom.to_string()
    |> String.replace_suffix("_component", "")
    |> String.to_atom()
  end

  defp registry_type(component),
    do:
      component
      |> registry_method()
      |> Atom.to_string()
      |> Macro.camelize()
      |> then(&String.to_atom("Component#{&1}"))
end

defmodule GPUI.Codegen.Native.Registry do
  @moduledoc false

  use RustQ.Meta

  alias GPUI.Codegen.Native.RegistryDefinitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  require RegistryDefinitions
  RegistryDefinitions.define_registry()

  @spec items() :: [AST.item()]
  def items do
    [
      type_item!(:ComponentKind, derive: [:Clone, :Copy, :Debug, :Eq, :Hash, :PartialEq]),
      type_item!(:StatefulComponent),
      impl_item!()
    ]
  end

  defp impl_item!, do: MetaAST.impl!(__MODULE__, :ComponentRegistry)

  defp type_item!(name, opts \\ []) do
    item = MetaAST.enum_type_item!(__MODULE__, name)

    %{item | derive: Keyword.get(opts, :derive, []), vis: nil}
  end
end
