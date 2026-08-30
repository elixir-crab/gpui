defmodule GPUI.Codegen.Native.ComponentEventTransportTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust

  test "generates exhaustive component value transport" do
    source = GPUI.Codegen.Native.ComponentEventTransport.items() |> Rust.render_all()

    for variant <- ~w(Boolean String Strings Number None) do
      assert source =~ "ComponentValue::#{variant}"
    end

    assert source =~ "Option<EventValue>"
    assert RustQ.valid?(source, "generated_component_event_transport.rs")
  end
end
