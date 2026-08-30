defmodule GPUI.Codegen.Native.CoreStyleApplication do
  @moduledoc "Generates complete vanilla-GPUI style application from Elixir style declarations."

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  @spec items() :: [AST.item()]
  def items do
    function = MetaAST.function!(GPUI.Codegen.Native.Style, :apply_generated_render_styles)

    args =
      Enum.map(function.args, fn
        %AST.FunctionArg{name: :style} = argument ->
          %{argument | type: A.type_path(:Style)}

        argument ->
          argument
      end)

    [
      %{
        function
        | name: :apply,
          args: args,
          vis: :pub,
          attrs: [
            A.attr(:cfg, feature: "native-render"),
            A.allow_attr(:unreachable_patterns),
            A.allow_attr(A.path([:clippy, :single_match]))
          ]
      }
    ]
  end
end
