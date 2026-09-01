defmodule GPUI.Codegen.Native.TextBoundaryTest do
  use RustQ.Test, async: true

  alias GPUI.Codegen.Native.TextBoundary
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST

  @functions [
    text_buffer_new: 3,
    text_buffer_snapshot: 1,
    text_buffer_transact: 2,
    text_buffer_undo: 2,
    text_buffer_redo: 2
  ]

  for {name, arity} <- @functions do
    test "exports #{name}/#{arity} as a dirty-CPU text boundary" do
      name = unquote(name)
      arity = unquote(arity)

      assert nif_exported?(TextBoundary, name, arity)
      function = MetaAST.function!(TextBoundary, name)

      assert Enum.any?(function.attrs, fn
               %AST.Attribute{path: [:rustler, :nif], args: [schedule: "DirtyCpu"]} -> true
               _attribute -> false
             end)
    end
  end

  test "uses generated text values and the handwritten buffer resource" do
    source = TextBoundary |> RustQ.Native.items() |> RustQ.Rust.render_all()

    assert source =~ "selections: Vec<TextSelection>"
    assert source =~ "buffer: ResourceArc<TextBufferResource>"
    assert source =~ "transaction: TextTransaction"
  end

  test "delegates text ownership to handwritten implementations" do
    assert rust_source!(TextBoundary, :text_buffer_new) =~
             "text_buffer_new_impl(env, text, revision, selections)"

    assert rust_source!(TextBoundary, :text_buffer_snapshot) =~
             "text_buffer_snapshot_impl(env, buffer)"

    assert rust_source!(TextBoundary, :text_buffer_transact) =~
             "text_buffer_transact_impl(env, buffer, transaction)"

    assert rust_source!(TextBoundary, :text_buffer_undo) =~
             "text_buffer_undo_impl(env, buffer, base_revision)"

    assert rust_source!(TextBoundary, :text_buffer_redo) =~
             "text_buffer_redo_impl(env, buffer, base_revision)"
  end
end
