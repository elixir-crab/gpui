defmodule GPUI.Codegen.Native.Rusty do
  @moduledoc "Defines RustQ-owned NIF entrypoints for GPUI's externally owned native crate."

  use RustQ.Native,
    otp_app: :gpui_native,
    build: false,
    load: false,
    rust_sources: ["apps/gpui_native/native/gpui/src/nif.rs"]

  alias RustQ.Type, as: R

  @nif schedule: :dirty_cpu
  @spec decode_image(binary()) :: R.nif_result(R.term())
  defnif(decode_image(bytes), do: decode_image_impl(nif_env(), bytes))
end
