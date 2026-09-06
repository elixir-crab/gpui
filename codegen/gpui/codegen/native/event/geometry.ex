defmodule GPUI.Codegen.Native.Event.Geometry do
  @moduledoc "Defines native text geometry wire payloads."

  use RustQ.Meta

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @type text_viewport_geometry :: %{
          required(:first_visible_row) => R.u64(),
          required(:last_visible_row) => R.u64(),
          required(:scroll_x) => R.f64(),
          required(:scroll_y) => R.f64(),
          required(:line_height) => R.f64()
        }

  @type text_caret_geometry :: %{
          required(:line) => R.u64(),
          required(:utf16_offset) => R.u64(),
          required(:x) => R.f64(),
          required(:y) => R.f64(),
          required(:width) => R.f64(),
          required(:height) => R.f64()
        }

  @type text_rectangle :: %{
          required(:x) => R.f64(),
          required(:y) => R.f64(),
          required(:width) => R.f64(),
          required(:height) => R.f64()
        }

  @type text_range_geometry :: %{
          required(:range) => Crate.TextRange.t(),
          required(:rectangles) => R.vec(TextRectangle.t())
        }

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    MetaAST.struct_type_items(
      __MODULE__,
      [:text_viewport_geometry, :text_caret_geometry, :text_rectangle, :text_range_geometry],
      derive: [:Clone, :Debug, :NifMap],
      vis: :crate,
      field_vis: :crate,
      attrs: [A.attr(:cfg, feature: "components")]
    )
  end
end
