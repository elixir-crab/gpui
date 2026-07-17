defmodule GPUI.Codegen.Native.Renderers do
  @moduledoc false

  alias RustQ.Syn
  alias RustQ.Syn.Type

  @source_root "native/gpui/src"
  @renderer_globs [
    "native/gpui/src/element/component.rs",
    "native/gpui/src/element/component/**/*.rs"
  ]

  @type renderer :: %{path: [atom()], args: [atom()]}

  @spec for_node!(atom()) :: renderer()
  def for_node!(node) do
    node_name = Atom.to_string(node)

    @renderer_globs
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.flat_map(&renderers_in/1)
    |> Enum.filter(&(&1.node == node_name))
    |> Enum.max_by(&length(&1.path), fn ->
      raise ArgumentError, "no native renderer accepts #{node_name}"
    end)
    |> Map.take([:path, :args])
  end

  defp renderers_in(path) do
    module = module_path(path)

    path
    |> Syn.parse_file!()
    |> Syn.functions()
    |> Enum.filter(&(Type.type_name(&1.returns_ast) == "AnyElement"))
    |> Enum.flat_map(fn function ->
      case Enum.find(function.args, &(node_type(&1) != nil)) do
        nil ->
          []

        node_arg ->
          [
            %{
              path: module ++ [String.to_atom(function.name)],
              node: node_type(node_arg),
              args: call_args(function.args)
            }
          ]
      end
    end)
  end

  defp call_args(args), do: Enum.map(args, &call_arg/1)

  defp call_arg(arg) do
    case Type.type_name(arg.type_ast) do
      "usize" -> :element_id
      "ElementRenderContext" -> :context
      name when is_binary(name) -> component_arg!(name, arg)
      _other -> unsupported_arg!(arg)
    end
  end

  defp component_arg!(name, arg) do
    if String.ends_with?(name, "ComponentNode"), do: :node, else: unsupported_arg!(arg)
  end

  defp node_type(arg) do
    name = Type.type_name(arg.type_ast)
    if is_binary(name) and String.ends_with?(name, "ComponentNode"), do: name
  end

  defp unsupported_arg!(arg),
    do: raise(ArgumentError, "unsupported native renderer argument #{inspect(arg)}")

  defp module_path(path) do
    path
    |> Path.relative_to(@source_root)
    |> Path.rootname()
    |> Path.split()
    |> Enum.map(&String.to_atom/1)
  end
end
