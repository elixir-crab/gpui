defmodule GPUI.Native do
  @moduledoc """
  Availability information for the optional native GPUI backend.

  Application code normally uses `GPUI.Runtime`, `GPUI.Display.Native`,
  `GPUI.Image`, and `GPUI.Text.Buffer` rather than calling the native backend
  directly. The latter three capabilities are provided by the `gpui_native`
  package; without it, native-backed APIs return
  `{:error, :native_backend_unavailable}`.
  """

  alias GPUI.Native.Backend

  @doc "Reports whether the configured native backend loaded successfully."
  @spec available?() :: boolean()
  def available?, do: Backend.available?()

  @doc "Deprecated alias for `available?/0`."
  @deprecated "Use available?/0"
  @spec compiled?() :: boolean()
  def compiled?, do: available?()
end
