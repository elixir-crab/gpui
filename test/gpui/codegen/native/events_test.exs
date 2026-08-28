defmodule GPUI.Codegen.Native.EventsTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Events
  alias RustQ.Rust
  alias RustQ.Rust.AST
  alias RustQ.Syn

  test "derives event value and input kind enums from RustQ types" do
    source = Events.items() |> Rust.render_all()
    parsed = Syn.parse!(source)

    enums = Map.new(Syn.enums(parsed), &{&1.name, &1.variants})

    assert enums["EventValue"] == ["String", "Strings", "Numbers", "Boolean", "Number", "Nil"]
    assert enums["InputKind"] == Enum.map(input_kinds(), &rust_variant/1)
    assert RustQ.valid?(source, "generated_events.rs")
  end

  test "input kinds remain derived from component event contracts" do
    input_kind =
      Events.items()
      |> Enum.find(&match?(%AST.Enum{name: :InputKind}, &1))

    assert Enum.map(input_kind.variants, & &1.name) ==
             Enum.map(input_kinds(), &String.to_atom(rust_variant(&1)))
  end

  test "generates encoder and atom methods from typed Rusty-Elixir implementations" do
    source = Events.items() |> Rust.render_all()

    assert source =~ "impl EventValue"
    assert source =~ "fn encode<'a>(&self, env: Env<'a>) -> Term<'a>"
    assert source =~ "Self::Nil => atoms::nil().encode(env)"
    assert source =~ "impl InputKind"
    assert source =~ "fn atom(&self) -> Atom"

    for kind <- input_kinds() do
      assert source =~ "Self::#{rust_variant(kind)} => atoms::#{kind}()"
    end
  end

  defp input_kinds do
    GPUI.Codegen.Native.Host.components()
    |> Enum.flat_map(&Keyword.keys(&1.events))
    |> Enum.uniq()
    |> Enum.reject(&(&1 == :click))
  end

  defp rust_variant(:keydown), do: "KeyDown"
  defp rust_variant(:keyup), do: "KeyUp"
  defp rust_variant(kind), do: kind |> Atom.to_string() |> Macro.camelize()
end
