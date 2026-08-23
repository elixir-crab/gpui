defmodule GPUI.Codegen.Native.ResourceBoundaryTest do
  use RustQ.Test, async: true

  alias GPUI.Codegen.Native.ResourceBoundary
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  test "generates typed resource requests and public wrappers" do
    source = rust_source!(ResourceBoundary)

    assert %AST.Struct{name: :PutRequest} = MetaAST.type_item!(ResourceBoundary, :PutRequest)
    assert %AST.Struct{name: :DropRequest} = MetaAST.type_item!(ResourceBoundary, :DropRequest)
    assert nif_exported?(ResourceBoundary, :put_resource, 3)
    assert nif_exported?(ResourceBoundary, :drop_resource, 2)
    assert source =~ "put_resource_impl(env, runtime, put_request(resource_id, resource))"
    assert source =~ "drop_resource_impl(env, runtime, drop_request(resource_id))"
  end

  test "keeps resource scheduling explicit" do
    assert dirty_cpu?(MetaAST.function!(ResourceBoundary, :put_resource))
    refute dirty_cpu?(MetaAST.function!(ResourceBoundary, :drop_resource))
  end

  for {name, arity, dirty_cpu?} <- [put_resource: {3, true}, drop_resource: {2, false}] do
    test "exports disabled #{name}/#{arity} with matching scheduling" do
      name = unquote(name)
      arity = unquote(arity)

      assert nif_exported?(GPUI.Codegen.Native.DisabledResourceBoundary, name, arity)

      assert dirty_cpu?(MetaAST.function!(GPUI.Codegen.Native.DisabledResourceBoundary, name)) ==
               unquote(dirty_cpu?)

      assert rust_source!(GPUI.Codegen.Native.DisabledResourceBoundary, name) =~
               "real_gpui_disabled()"
    end
  end

  defp dirty_cpu?(function) do
    Enum.any?(function.attrs, fn
      %AST.Attribute{path: [:rustler, :nif], args: [schedule: "DirtyCpu"]} -> true
      _attribute -> false
    end)
  end
end
