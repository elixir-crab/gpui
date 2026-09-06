defmodule GPUI.Codegen.Native.DisabledResourceBoundary do
  @moduledoc "Defines RustQ-owned resource NIF fallbacks without real GPUI."

  use RustQ.Native,
    otp_app: :gpui_native,
    build: false,
    load: false,
    rust_sources: ["apps/gpui_native/native/src/disabled.rs"]

  alias RustQ.Type, as: R

  @nif schedule: :dirty_cpu
  @spec put_resource(
          R.resource(R.path(:RuntimeResource)),
          String.t(),
          term()
        ) :: R.nif_result(term())
  defnif(put_resource(_runtime, _resource_id, _resource), do: real_gpui_disabled())

  @spec drop_resource(
          R.resource(R.path(:RuntimeResource)),
          String.t()
        ) :: R.nif_result(term())
  defnif(drop_resource(_runtime, _resource_id), do: real_gpui_disabled())
end
