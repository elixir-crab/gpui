defmodule GPUI.Codegen.Native.RegistryDefinitions do
  @moduledoc false

  defmacro define_registry do
    components = GPUI.Schema.stateful_components()

    component_kind_variants = Enum.map(components, &{registry_method(&1), []})

    stateful_component_variants =
      Enum.map(components, fn component ->
        {registry_method(component), [quote(do: R.path(unquote(registry_type(component))))]}
      end)

    functions = Enum.flat_map(components, &[getter(&1), inserter(&1)])

    quote do
      @type component_kind :: R.enum(unquote(component_kind_variants))
      @type stateful_component :: R.enum(unquote(stateful_component_variants))

      unquote_splicing(functions)
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
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require RegistryDefinitions
  RegistryDefinitions.define_registry()

  @spec items() :: [AST.item()]
  def items do
    [
      type_item!(:ComponentKind, derive: [:Clone, :Copy, :Debug, :Eq, :Hash, :PartialEq]),
      type_item!(:StatefulComponent),
      registry_impl()
    ]
  end

  defp registry_impl do
    functions =
      __MODULE__.__rustq_asts__()
      |> Enum.filter(&match?(%AST.Function{}, &1))
      |> Enum.map(&as_method/1)

    A.impl(:ComponentRegistry, items: functions)
  end

  defp as_method(%AST.Function{args: [first | rest]} = function) do
    receiver = %{first | name: :self, receiver: true, mutable: true, type: nil}
    %{function | args: [receiver | rest], vis: :crate}
  end

  defp type_item!(name, opts \\ []) do
    item =
      Enum.find(__MODULE__.__rustq_type_items__(), &match?(%AST.Enum{name: ^name}, &1)) ||
        raise "missing generated registry enum #{name}"

    %{item | derive: Keyword.get(opts, :derive, []), vis: nil}
  end
end
