defmodule GPUI.Codegen.Native.RuntimeBoundaryTest do
  use RustQ.Test, async: true

  alias GPUI.Codegen.Native.RuntimeBoundary
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  for {name, arity} <- [start_runtime: 0, stop_runtime: 1] do
    test "exports #{name}/#{arity} as a dirty-I/O runtime boundary" do
      name = unquote(name)
      arity = unquote(arity)

      assert nif_exported?(RuntimeBoundary, name, arity)
      function = MetaAST.function!(RuntimeBoundary, name)

      assert Enum.any?(function.attrs, fn
               %AST.Attribute{path: [:rustler, :nif], args: [schedule: "DirtyIo"]} -> true
               _attribute -> false
             end)
    end
  end

  test "delegates lifecycle ownership to handwritten runtime implementations" do
    assert rust_source!(RuntimeBoundary, :start_runtime) =~ "start_runtime_impl(env)"
    assert rust_source!(RuntimeBoundary, :stop_runtime) =~ "stop_runtime_impl(env, runtime)"
  end
end
