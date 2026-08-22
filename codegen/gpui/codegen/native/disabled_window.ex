defmodule GPUI.Codegen.Native.DisabledWindow do
  @moduledoc "Defines RustQ-owned fallbacks for window NIFs without real GPUI."

  use RustQ.Native,
    build: false,
    load: false,
    rust_sources: ["native/gpui/src/disabled.rs"]

  alias RustQ.Type, as: R

  @nif schedule: :dirty_io
  @spec update_window(
          R.resource(R.path(:RuntimeResource)),
          R.u64(),
          term()
        ) :: R.nif_result(term())
  defnif update_window(_runtime, _window_id, _tree), do: real_gpui_disabled()

  @nif schedule: :dirty_io
  @spec close_window(
          R.resource(R.path(:RuntimeResource)),
          R.u64()
        ) :: R.nif_result(term())
  defnif close_window(_runtime, _window_id), do: real_gpui_disabled()

  @nif schedule: :dirty_io
  @spec await_frame(
          R.resource(R.path(:RuntimeResource)),
          R.u64(),
          R.u64()
        ) :: R.nif_result(term())
  defnif await_frame(_runtime, _window_id, _timeout_ms), do: real_gpui_disabled()

  @nif schedule: :dirty_io
  @spec frame_token(
          R.resource(R.path(:RuntimeResource)),
          R.u64()
        ) :: R.nif_result(term())
  defnif frame_token(_runtime, _window_id), do: real_gpui_disabled()

  @nif schedule: :dirty_io
  @spec await_frame_after(
          R.resource(R.path(:RuntimeResource)),
          R.u64(),
          R.u64(),
          R.u64()
        ) :: R.nif_result(term())
  defnif await_frame_after(_runtime, _window_id, _generation, _timeout_ms),
    do: real_gpui_disabled()
end
