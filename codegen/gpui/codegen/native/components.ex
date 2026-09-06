defmodule GPUI.Codegen.Native.Component.Definitions do
  @moduledoc "Emits generated Rust component node definitions and decoders."

  use RustQ.Meta

  alias GPUI.Codegen.Native.Component.Macros
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require Macros
  Macros.define_components(:gpui_component)

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
