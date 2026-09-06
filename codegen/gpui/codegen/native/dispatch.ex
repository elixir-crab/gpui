defmodule GPUI.Codegen.Native.Dispatch do
  @moduledoc "Emits generated native element-tag and component-kind decoder dispatch."

  use RustQ.Meta,
    callable_modules: [GPUI.Codegen.Native.Component.Definitions]

  alias GPUI.Codegen.Native.Dispatch.Definitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  require Definitions
  Definitions.define_dispatch(:gpui_component)

  @spec items() :: [AST.item()]
  def items do
    Enum.map(MetaAST.functions(__MODULE__), fn
      %{name: :decode_generated_element_tag} = function ->
        %{function | vis: :pub}

      %{name: :generated_component_kind} = function ->
        %{function | vis: :pub}

      function ->
        %{function | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | function.attrs]}
    end)
  end
end
