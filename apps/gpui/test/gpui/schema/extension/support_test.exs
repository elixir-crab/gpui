defmodule GPUI.Schema.Extension.SupportTest do
  use ExUnit.Case, async: true

  alias GPUI.Schema.Extension.Support

  test "native display advertises only implemented presentation mechanics" do
    assert {:ok, supports} = GPUI.Display.Native.presentation_capabilities(:not_started)

    assert Enum.any?(supports, &Support.provides?(&1, :edge_fade, 1, :linear_gradient))
    assert Enum.any?(supports, &Support.provides?(&1, :paint, 1, :rect))
    assert Enum.any?(supports, &Support.provides?(&1, :frost, 1, :reduced_transparency))
    refute Enum.any?(supports, &Support.provides?(&1, :frost, 1, :backdrop_blur))
  end

  test "validates exact versions and the contract capability vocabulary" do
    assert {:ok,
            %Support{
              id: :frost,
              version: 1,
              capabilities: [:solid_fallback, :reduced_transparency]
            } = support} = Support.new(:frost, 1, [:solid_fallback, :reduced_transparency])

    assert Support.provides?(support, :frost, 1)
    assert Support.provides?(support, :frost, 1, :solid_fallback)

    assert {:error, {:unknown_capabilities, [:backdrop_blur]}} =
             Support.new(:frost, 1, [:backdrop_blur])

    refute Support.provides?(support, :frost, 1, :backdrop_blur)
    refute Support.provides?(support, :frost, 2)
    refute Support.provides?(support, :paint, 1)

    assert {:error, {:unsupported_version, 1, 2}} = Support.new(:frost, 2, [])
    assert {:error, {:unknown_extension, :widget}} = Support.new(:widget, 1, [])

    assert {:error, {:unknown_capabilities, [:backdrop_shader]}} =
             Support.new(:frost, 1, [:backdrop_shader])

    assert {:error, :duplicate_capabilities} =
             Support.new(:paint, 1, [:rect, :rect])
  end
end
