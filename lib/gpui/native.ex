defmodule GPUI.Native do
  @moduledoc false

  use Rustler, otp_app: :gpui, crate: :gpui_nif, path: "native/gpui"
  use GPUI.Native.Generated
end
