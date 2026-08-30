defmodule GPUI.Codegen.Native.ComponentEventTransport do
  @moduledoc "Generates NIF transport conversion for component event values."

  use RustQ.Meta

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @type component_value ::
          R.enum(
            boolean: [boolean()],
            string: [String.t()],
            strings: [R.vec(String.t())],
            number: [R.f64()],
            none: []
          )

  @type event_value ::
          R.enum(
            string: [String.t()],
            strings: [R.vec(String.t())],
            boolean: [boolean()],
            number: [R.f64()]
          )

  @spec component_value_to_event_value(component_value()) :: R.option(event_value())
  defrust component_value_to_event_value(value) do
    case value do
      enum_variant(ComponentValue, :boolean, value) ->
        some(enum_variant(EventValue, :boolean, value))

      enum_variant(ComponentValue, :string, value) ->
        some(enum_variant(EventValue, :string, value))

      enum_variant(ComponentValue, :strings, value) ->
        some(enum_variant(EventValue, :strings, value))

      enum_variant(ComponentValue, :number, value) ->
        some(enum_variant(EventValue, :number, value))

      enum_variant(ComponentValue, :none) -> nil
    end
  end

  @spec items() :: [AST.item()]
  def items do
    MetaAST.functions(__MODULE__)
    |> Enum.map(&%{&1 | vis: :crate, attrs: [A.attr(:cfg, feature: "components") | &1.attrs]})
  end
end
