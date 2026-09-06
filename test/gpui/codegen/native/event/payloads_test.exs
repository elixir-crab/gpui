defmodule GPUI.Codegen.Native.Event.PayloadsTest do
  use ExUnit.Case, async: true

  alias GPUI.Codegen.Native.Event.Payloads
  alias RustQ.Rust
  alias RustQ.Rust.AST

  test "payload declarations preserve wire shapes and conditional availability" do
    items = Map.new(Payloads.items(), &{&1.name, &1})
    fields = fn name -> Enum.map(items[name].fields, & &1.name) end
    assert fields.(:ElementBoundsGeometry) == [:id, :x, :y, :width, :height, :coordinate_space]
    assert fields.(:TransferPayload) == [:text, :external_paths]

    assert fields.(:TransferEventValue) == [
             :session_id,
             :target_id,
             :x,
             :y,
             :coordinate_space,
             :payload
           ]

    assert [%AST.Attribute{path: [:cfg], args: [feature: "real-gpui"]}] =
             items[:ElementBoundsGeometry].attrs

    for name <- [:TransferPayload, :TransferEventValue] do
      assert [
               %AST.Attribute{
                 path: [:cfg_attr],
                 args: [not: [feature: "components"], allow: [:dead_code]]
               }
             ] = items[name].attrs
    end

    assert RustQ.valid?(Rust.render_all(Map.values(items)), "event_payloads.rs")
  end
end
