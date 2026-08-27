defmodule GPUI.Codegen.Native.Extensions do
  @moduledoc "Generates native constants for schema-owned presentation extension contracts."

  alias RustQ.Rust.AST.Builder, as: A

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    GPUI.Codegen.Native.Host.extensions()
    |> Enum.flat_map(fn extension ->
      prefix = extension.id |> Atom.to_string() |> String.upcase()

      [
        A.const(String.to_atom("#{prefix}_EXTENSION_VERSION"), :u32, extension.version,
          vis: :pub
        ),
        A.const(
          String.to_atom("#{prefix}_EXTENSION_CAPABILITIES"),
          {:ref, {:slice, {:ref, :str}}},
          extension.capabilities |> Enum.map(&Atom.to_string/1) |> A.slice(),
          vis: :pub
        )
      ]
    end)
  end
end
