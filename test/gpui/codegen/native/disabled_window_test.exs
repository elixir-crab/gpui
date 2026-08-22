defmodule GPUI.Codegen.Native.DisabledWindowTest do
  use RustQ.Test, async: true

  alias GPUI.Codegen.Native.DisabledWindow
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  for {name, arity} <- [
        update_window: 3,
        close_window: 2,
        await_frame: 3,
        frame_token: 2,
        await_frame_after: 4
      ] do
    test "exports #{name}/#{arity} as a dirty-I/O disabled-native fallback" do
      name = unquote(name)
      arity = unquote(arity)

      assert nif_exported?(DisabledWindow, name, arity)
      function = MetaAST.function!(DisabledWindow, name)

      assert Enum.any?(function.attrs, fn
               %AST.Attribute{path: [:rustler, :nif], args: [schedule: "DirtyIo"]} -> true
               _attribute -> false
             end)

      assert rust_source!(DisabledWindow, name) =~ "real_gpui_disabled()"
    end
  end
end
