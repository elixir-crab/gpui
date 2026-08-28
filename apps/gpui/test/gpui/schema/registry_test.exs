defmodule GPUI.Schema.RegistryTest do
  use ExUnit.Case, async: true

  alias GPUI.Schema.Registry

  defmodule FirstSchema do
    @behaviour GPUI.Schema.Provider
    @impl true
    def components, do: [%GPUI.Schema.Component{tag: :first, kind: :container}]
  end

  defmodule SecondSchema do
    @behaviour GPUI.Schema.Provider
    @impl true
    def components, do: [%GPUI.Schema.Component{tag: :second, kind: :container}]
  end

  defmodule DuplicateSchema do
    @behaviour GPUI.Schema.Provider
    @impl true
    def components, do: [%GPUI.Schema.Component{tag: :first, kind: :text}]
  end

  test "composes explicitly selected schema modules in declaration order" do
    registry =
      Registry.new()
      |> Registry.include(FirstSchema)
      |> Registry.include(SecondSchema)

    assert registry.modules == [FirstSchema, SecondSchema]
    assert Registry.native_tags(registry) == [:first, :second]
    assert Registry.component!(registry, :second).kind == :container
    assert Registry.provider!(registry, :first) == FirstSchema

    assert Registry.entries(registry) == [
             %{provider: FirstSchema, component: Registry.component!(registry, :first)},
             %{provider: SecondSchema, component: Registry.component!(registry, :second)}
           ]
  end

  test "canonical core registry contains neutral declarations" do
    registry = GPUI.Schema.registry()

    assert :div in Registry.native_tags(registry)
    refute :ui_button in Registry.native_tags(registry)
  end

  test "rejects duplicate tags across schema modules" do
    registry = Registry.new() |> Registry.include(FirstSchema)

    assert_raise ArgumentError, ~r/duplicates component tags \[:first\]/, fn ->
      Registry.include(registry, DuplicateSchema)
    end
  end
end
