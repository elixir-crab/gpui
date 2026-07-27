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
    [
      SchemaTypes.component_kind_item(),
      Decoder.asts(),
      Elements.items(),
      Style.items(GPUI.Schema.style_specs()),
      ComponentContracts.items(),
      ComponentDefinitions.items(),
      SchemaTypes.element_node_item(),
      SchemaTypes.element_tag_item(),
      Dispatch.items(),
      RendererDispatch.item()
    ]
    |> List.flatten()
  end

  @spec registry_items() :: [AST.item()]
  def registry_items, do: Registry.items()
end
