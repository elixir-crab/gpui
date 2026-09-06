defmodule GPUI.Codegen.Native.TestOperations do
  @moduledoc "Encodes native test operation results without owning test execution."

  use RustQ.Meta,
    rust_sources: ["apps/gpui_native/native/src/native_test.rs"]

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Type, as: R

  defmacro encode_unit_result(env, operation) do
    quote do
      case unquote(operation) do
        {:ok, _unit} -> {:ok, {Atoms.ok(), Atoms.ok()}.encode(unquote(env))}
        {:error, reason} -> {:ok, {Atoms.error(), reason}.encode(unquote(env))}
      end
    end
  end

  @spec native_test_focus_impl(
          R.path(:Env, R.lifetime(:a)),
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.path(:TargetRequest)
        ) :: R.nif_result(term())
  defrust native_test_focus_impl(env, session, request) do
    encode_unit_result(env, focus(ref(session), request.target))
  end

  @spec native_test_click_impl(
          R.path(:Env, R.lifetime(:a)),
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.path(:TargetRequest)
        ) :: R.nif_result(term())
  defrust native_test_click_impl(env, session, request) do
    encode_unit_result(env, click(ref(session), request.target))
  end

  @spec native_test_input_impl(
          R.path(:Env, R.lifetime(:a)),
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.path(:InputRequest)
        ) :: R.nif_result(term())
  defrust native_test_input_impl(env, session, request) do
    encode_unit_result(env, input(ref(session), request.text))
  end

  @spec native_test_key_impl(
          R.path(:Env, R.lifetime(:a)),
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.path(:KeyRequest)
        ) :: R.nif_result(term())
  defrust native_test_key_impl(env, session, request) do
    encode_unit_result(env, key(ref(session), request.key))
  end

  @spec native_test_advance_impl(
          R.path(:Env, R.lifetime(:a)),
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.path(:AdvanceRequest)
        ) :: R.nif_result(term())
  defrust native_test_advance_impl(env, session, request) do
    encode_unit_result(env, advance(ref(session), request.milliseconds))
  end

  @spec items() :: [RustQ.Rust.AST.item()]
  def items, do: Enum.map(MetaAST.functions(__MODULE__), &%{&1 | vis: :crate})
end
