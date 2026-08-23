defmodule GPUI.Codegen.Native.TextBoundary do
  @moduledoc "Defines RustQ-owned persistent text-buffer NIF boundaries."

  use RustQ.Native,
    build: false,
    load: false,
    rust_sources: ["native/gpui/src/nif.rs"]

  alias RustQ.Type, as: R

  @nif schedule: :dirty_cpu
  @spec text_buffer_new(String.t(), R.u64(), R.vec(R.path(:TextSelection))) ::
          R.nif_result(term())
  defnif text_buffer_new(text, revision, selections) do
    text_buffer_new_impl(nif_env(), text, revision, selections)
  end

  @nif schedule: :dirty_cpu
  @spec text_buffer_snapshot(R.resource(R.path(:TextBufferResource))) :: R.nif_result(term())
  defnif text_buffer_snapshot(buffer), do: text_buffer_snapshot_impl(nif_env(), buffer)

  @nif schedule: :dirty_cpu
  @spec text_buffer_transact(
          R.resource(R.path(:TextBufferResource)),
          R.path(:TextTransaction)
        ) :: R.nif_result(term())
  defnif text_buffer_transact(buffer, transaction) do
    text_buffer_transact_impl(nif_env(), buffer, transaction)
  end

  @nif schedule: :dirty_cpu
  @spec text_buffer_undo(R.resource(R.path(:TextBufferResource)), R.u64()) ::
          R.nif_result(term())
  defnif text_buffer_undo(buffer, base_revision) do
    text_buffer_undo_impl(nif_env(), buffer, base_revision)
  end

  @nif schedule: :dirty_cpu
  @spec text_buffer_redo(R.resource(R.path(:TextBufferResource)), R.u64()) ::
          R.nif_result(term())
  defnif text_buffer_redo(buffer, base_revision) do
    text_buffer_redo_impl(nif_env(), buffer, base_revision)
  end
end
