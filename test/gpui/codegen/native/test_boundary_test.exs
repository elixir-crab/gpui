defmodule GPUI.Codegen.Native.TestBoundaryTest do
  use RustQ.Test, async: true

  alias GPUI.Codegen.Native.TestBoundary
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  for {name, arity} <- [
        native_test_start: 2,
        native_test_render: 2,
        native_test_resize: 3,
        native_test_bounds: 2,
        native_test_focus: 2,
        native_test_click: 2,
        native_test_click_at: 3,
        native_test_scroll: 4,
        native_test_idle: 1,
        native_test_events: 1,
        native_test_stop: 1
      ] do
    test "exports #{name}/#{arity} as dirty I/O" do
      name = unquote(name)
      arity = unquote(arity)

      assert nif_exported?(TestBoundary, name, arity)
      function = MetaAST.function!(TestBoundary, name)

      assert Enum.any?(function.attrs, fn
               %AST.Attribute{path: [:rustler, :nif], args: [schedule: "DirtyIo"]} -> true
               _attribute -> false
             end)
    end
  end

  test "delegates lifecycle commands to the handwritten worker boundary" do
    source = rust_source!(TestBoundary)

    assert %AST.Struct{name: :RenderRequest} =
             MetaAST.type_item!(TestBoundary, :RenderRequest)

    assert %AST.Struct{name: :ResizeRequest} =
             MetaAST.type_item!(TestBoundary, :ResizeRequest)

    assert %AST.Struct{name: :TargetRequest} =
             MetaAST.type_item!(TestBoundary, :TargetRequest)

    assert %AST.Struct{name: :PointRequest} =
             MetaAST.type_item!(TestBoundary, :PointRequest)

    assert %AST.Struct{name: :ScrollRequest} =
             MetaAST.type_item!(TestBoundary, :ScrollRequest)

    assert source =~ "native_test_start_impl(env, width, height)"
    assert source =~ "native_test_render_impl(env, session, render_request(tree))"
    assert source =~ "native_test_resize_impl(env, session, resize_request(width, height))"
    assert source =~ "native_test_bounds_impl(env, session, target_request(target))"
    assert source =~ "native_test_focus_impl(env, session, target_request(target))"
    assert source =~ "native_test_click_impl(env, session, target_request(target))"
    assert source =~ "native_test_click_at_impl(env, session, point_request(x, y))"

    assert source =~
             "native_test_scroll_impl(env, session, scroll_request(target, delta_x, delta_y))"

    assert source =~ "native_test_idle_impl(env, session)"
    assert source =~ "native_test_events_impl(env, session)"
    assert source =~ "native_test_stop_impl(env, session)"
    assert RustQ.valid?(source, "generated_test_boundary.rs")
  end
end
