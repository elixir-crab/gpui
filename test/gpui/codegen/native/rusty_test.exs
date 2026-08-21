defmodule GPUI.Codegen.Native.RustyTest do
  use RustQ.Test, async: true

  alias GPUI.Codegen.Native.Boundary
  alias GPUI.Codegen.Native.Rusty
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  test "exports image decoding through the explicit dirty-CPU boundary" do
    assert nif_exported?(Rusty, :decode_image, 1)

    function = MetaAST.function!(Rusty, :decode_image)

    assert Enum.any?(function.attrs, fn
             %AST.Attribute{
               path: [:rustler, :nif],
               args: [schedule: "DirtyCpu"]
             } ->
               true

             _attribute ->
               false
           end)

    assert Boundary.rusty_nifs() == [decode_image: [schedule: :dirty_cpu]]
  end

  test "generates a valid adapter to the handwritten bounded decoder" do
    source = rust_source!(Rusty, :decode_image)

    assert source =~ "decode_image_impl(env, bytes)"
    assert source =~ ~r/fn decode_image<'a>\(env: Env<'a>, bytes: Binary<'a>\)/
    assert RustQ.valid?(source, "generated_decode_image.rs")
  end
end
