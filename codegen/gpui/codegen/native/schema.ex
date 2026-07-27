defmodule GPUI.Codegen.Native.Schema do
  @moduledoc false

  alias GPUI.Codegen.Native.ComponentContracts
  alias GPUI.Codegen.Native.ComponentDefinitions
  alias GPUI.Codegen.Native.Decoder
  alias GPUI.Codegen.Native.Dispatch
  alias GPUI.Codegen.Native.Elements
  alias GPUI.Codegen.Native.Registry
  alias GPUI.Codegen.Native.RendererDispatch
  alias GPUI.Codegen.Native.SchemaTypes
  alias GPUI.Codegen.Native.Style
  alias RustQ.Rust.AST

  @spec items() :: [AST.item()]
  def items do
    components = GPUI.Schema.components()

    [
      SchemaTypes.component_kind_item(),
      generated_decoder_helpers(),
      Style.items(GPUI.Schema.style_specs()),
      generated_component_contracts(components),
      SchemaTypes.element_node_item(),
      SchemaTypes.element_tag_item(),
      Dispatch.items(),
      RendererDispatch.item()
    ]
    |> List.flatten()
  end

  @spec registry_items() :: [AST.item()]
  def registry_items, do: Registry.items()

  defp generated_decoder_helpers, do: Decoder.asts() ++ Elements.items()

  defp generated_component_contracts(_components) do
    ComponentContracts.items() ++ ComponentDefinitions.items()
  end
end
