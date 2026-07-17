defmodule GPUI.Codegen.Native.Atoms do
  @moduledoc false

  @renamed_atoms [{:type_atom, "type"}]

  @spec all() :: [{atom(), String.t()}]
  def all do
    source_atoms = Enum.map(source_atoms() ++ generated_atoms(), &{String.to_atom(&1), &1})

    (@renamed_atoms ++ schema_atoms() ++ source_atoms)
    |> Enum.uniq_by(fn {name, _value} -> name end)
    |> Enum.uniq_by(fn {_name, value} -> value end)
    |> Enum.sort_by(fn {name, _value} -> Atom.to_string(name) end)
  end

  defp source_atoms do
    "native/gpui/src/**/*.rs"
    |> Path.wildcard()
    |> Enum.reject(&String.contains?(&1, "/generated/"))
    |> Enum.flat_map(fn path ->
      path
      |> File.read!()
      |> RustQ.Syn.atom_references!()
    end)
    |> Enum.uniq()
  end

  defp generated_atoms do
    GPUI.Codegen.Native.Decoder.asts()
    |> collect_atom_references()
    |> Enum.uniq()
  end

  defp collect_atom_references(%RustQ.Rust.AST.PathCall{
         path: %RustQ.Rust.AST.Path{parts: [:atoms, name]}
       }),
       do: [Atom.to_string(name)]

  defp collect_atom_references(%module{} = node) when is_atom(module) do
    node
    |> Map.from_struct()
    |> Map.values()
    |> Enum.flat_map(&collect_atom_references/1)
  end

  defp collect_atom_references(values) when is_list(values),
    do: Enum.flat_map(values, &collect_atom_references/1)

  defp collect_atom_references(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.flat_map(&collect_atom_references/1)

  defp collect_atom_references(value) when is_map(value),
    do: value |> Map.values() |> Enum.flat_map(&collect_atom_references/1)

  defp collect_atom_references(_value), do: []

  defp schema_atoms do
    component_atoms =
      Enum.flat_map(GPUI.Schema.components(), fn component ->
        Keyword.keys(component.attrs) ++
          Keyword.keys(component.events) ++ Keyword.values(component.events)
      end)

    resource_atoms =
      Enum.flat_map(GPUI.Schema.resource_specs(), fn resource ->
        [resource.name | Keyword.keys(resource.fields)]
      end)

    (component_atoms ++ resource_atoms ++ GPUI.Schema.styles())
    |> Enum.uniq()
    |> Enum.map(fn atom -> {rust_name(atom), Atom.to_string(atom)} end)
  end

  defp rust_name(atom) do
    atom
    |> Atom.to_string()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> String.to_atom()
  end
end
