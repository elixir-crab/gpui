defmodule GPUI.Codegen.Native.Event.ContractTest do
  use ExUnit.Case, async: true
  alias GPUI.Codegen.Native.Event.Contract
  alias RustQ.Rust
  alias RustQ.Rust.AST

  test "every event variant has a matching gated encoder arm" do
    [
      %AST.Enum{variants: variants},
      %AST.Function{body: [%AST.Return{expr: %AST.Match{arms: arms}}]}
    ] = Contract.items()

    assert Enum.map(variants, & &1.name) == [
             :Copy,
             :Click,
             :Command,
             :Input,
             :Transaction,
             :Selection,
             :Viewport,
             :Geometry,
             :RangeGeometry,
             :HitTest,
             :Focus,
             :Bounds,
             :ClipboardWrite,
             :ClipboardRead,
             :Transfer,
             :WindowCloseRequest,
             :WindowFocus,
             :WindowClosed,
             :VirtualRange,
             :FileDialog,
             :MissingResource
           ]

    assert length(arms) == length(variants)

    for {variant, arm} <- Enum.zip(variants, arms) do
      assert arm.attrs == variant.attrs

      assert %AST.PatStruct{path: %AST.Path{parts: [:NativeEvent, name]}, fields: fields} =
               arm.pattern

      assert name == variant.name
      assert Enum.map(fields, &elem(&1, 0)) == Enum.map(variant.fields, & &1.name)
    end
  end

  test "file dialog encoding propagates allocation failures before encoding the envelope" do
    source = Contract.items() |> Rust.render_all()
    assert source =~ "encode_file_dialog_result(env, operation_id, result)?"
    assert source =~ "encode_file_dialog_event("
    assert source =~ "atoms::window_focus()"
    assert source =~ "atoms::window_blur()"
    assert RustQ.valid?(source, "event_contract.rs")
  end
end
