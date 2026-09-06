defmodule GPUI.Codegen.Native.Event.GeometryTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Event.Geometry
  alias RustQ.Rust

  test "geometry codecs preserve their typed public payload fields" do
    contracts = [
      {:TextViewportGeometry, GPUI.Text.Viewport},
      {:TextCaretGeometry, GPUI.Text.CaretGeometry},
      {:TextRectangle, GPUI.Text.Rectangle},
      {:TextRangeGeometry, GPUI.Text.RangeGeometry}
    ]

    items = Geometry.items()

    for {name, module} <- contracts do
      item = Enum.find(items, &(&1.name == name))
      expected = module.__struct__() |> Map.from_struct() |> Map.keys() |> Enum.sort()
      assert item.fields |> Enum.map(& &1.name) |> Enum.sort() == expected
      assert :NifMap in item.derive
    end

    assert RustQ.valid?(Rust.render_all(items), "event_geometry.rs")
  end
end
