defmodule GPUI.Codegen.Native.ComponentHostContract do
  @moduledoc "Generates the statically linked component-host contract from Elixir declarations."

  use RustQ.Meta

  alias GPUI.Codegen.Native.ComponentHostContract.Definitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  require Definitions
  Definitions.define_contract()

  @spec items() :: [AST.item()]
  def items do
    value = MetaAST.enum_type_item!(__MODULE__, :ComponentValue)
    event = MetaAST.enum_type_item!(__MODULE__, :ComponentEvent)

    [
      %{value | derive: [:Clone, :Debug, :PartialEq], vis: :pub},
      %{event | derive: [:Clone, :Debug, :PartialEq], vis: :pub}
    ]
  end
end
