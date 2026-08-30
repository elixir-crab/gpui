defmodule GPUI.Codegen.Native.Atoms do
  @moduledoc "Collects and names the Elixir atoms required by generated Rustler code."

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Walk

  @renamed_atoms [{:type_atom, "type"}, {:content, "content"}]

  @spec all() :: [{atom(), String.t()}]
  def all do
    source_atoms = Enum.map(source_atoms() ++ generated_atoms(), &{String.to_atom(&1), &1})

    (@renamed_atoms ++ schema_atoms() ++ source_atoms)
    |> Enum.uniq_by(fn {name, _value} -> name end)
    |> Enum.uniq_by(fn {_name, value} -> value end)
    |> Enum.sort_by(fn {name, _value} -> Atom.to_string(name) end)
  end

  defp source_atoms do
    "apps/gpui_native/native/src/**/*.rs"
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
    [
      GPUI.Codegen.Native.ComponentContracts.items(),
      GPUI.Codegen.Native.Decoder.asts(),
      GPUI.Codegen.Native.Elements.asts(),
      GPUI.Codegen.Native.Events.items(),
      GPUI.Codegen.Native.Style.items(GPUI.Schema.style_specs()),
      RustQ.Native.items(GPUI.Codegen.Native.Window)
    ]
    |> Walk.reduce(MapSet.new(), fn
      %AST.PathCall{path: %AST.Path{parts: [:atoms, name]}}, atoms ->
        MapSet.put(atoms, Atom.to_string(name))

      _node, atoms ->
        atoms
    end)
    |> MapSet.to_list()
  end

  defp schema_atoms do
    component_atoms =
      Enum.flat_map(GPUI.Codegen.Native.Host.components(:gpui_component), fn component ->
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
