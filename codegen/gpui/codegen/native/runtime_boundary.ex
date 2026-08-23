defmodule GPUI.Codegen.Native.RuntimeBoundary do
  @moduledoc "Defines RustQ-owned native runtime lifecycle NIF boundaries."

  use RustQ.Native,
    build: false,
    load: false,
    rust_sources: ["native/gpui/src/nif.rs"]

  alias RustQ.Type, as: R

  @nif schedule: :dirty_io
  @spec start_runtime() :: R.nif_result(term())
  defnif start_runtime(), do: start_runtime_impl(nif_env())

  @nif schedule: :dirty_io
  @spec stop_runtime(R.resource(R.path(:RuntimeResource))) :: R.nif_result(term())
  defnif stop_runtime(runtime), do: stop_runtime_impl(nif_env(), runtime)
end
