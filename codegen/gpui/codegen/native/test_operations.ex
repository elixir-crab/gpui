defmodule GPUI.Codegen.Native.TestOperations do
  @moduledoc "Encodes native test operation results without owning test execution."

  use RustQ.Meta,
    rust_sources: ["apps/gpui_native/native/src/native_test.rs"]

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Type, as: R

  @spec native_test_focus_impl(
          R.path(:Env, R.lifetime(:a)),
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.path(:TargetRequest)
        ) :: R.nif_result(term())
  defrust native_test_focus_impl(env, session, request) do
    case focus(ref(session), request.target) do
      {:ok, _unit} -> {:ok, {Atoms.ok(), Atoms.ok()}.encode(env)}
      {:error, reason} -> {:ok, {Atoms.error(), reason}.encode(env)}
    end
  end

  @spec native_test_click_impl(
          R.path(:Env, R.lifetime(:a)),
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.path(:TargetRequest)
        ) :: R.nif_result(term())
  defrust native_test_click_impl(env, session, request) do
    case click(ref(session), request.target) do
      {:ok, _unit} -> {:ok, {Atoms.ok(), Atoms.ok()}.encode(env)}
      {:error, reason} -> {:ok, {Atoms.error(), reason}.encode(env)}
    end
  end

  @spec items() :: [RustQ.Rust.AST.item()]
  def items, do: Enum.map(MetaAST.functions(__MODULE__), &%{&1 | vis: :crate})
end
