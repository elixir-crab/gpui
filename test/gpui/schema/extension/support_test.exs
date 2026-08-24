defmodule GPUI.Schema.Extension.SupportTest do
  use ExUnit.Case, async: true

  alias GPUI.Schema.Extension.Support

  test "validates exact versions and the contract capability vocabulary" do
    assert {:ok,
            %Support{
              id: :frost,
              version: 1,
              capabilities: [:solid_fallback, :reduced_transparency]
            } = support} = Support.new(:frost, 1, [:solid_fallback, :reduced_transparency])

    assert Support.compatible?(support, :frost, 1)
    assert Support.compatible?(support, :frost, 1, :solid_fallback)
    refute Support.compatible?(support, :frost, 1, :backdrop_blur)
    refute Support.compatible?(support, :frost, 2)
    refute Support.compatible?(support, :paint, 1)

    assert {:error, {:unsupported_version, 1, 2}} = Support.new(:frost, 2, [])
    assert {:error, {:unknown_extension, :widget}} = Support.new(:widget, 1, [])

    assert {:error, {:unknown_capabilities, [:backdrop_shader]}} =
             Support.new(:frost, 1, [:backdrop_shader])

    assert {:error, :duplicate_capabilities} =
             Support.new(:paint, 1, [:rect, :rect])
  end
end
