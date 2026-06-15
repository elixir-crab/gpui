defmodule GPUI.Native do
  @moduledoc false

  use Rustler, otp_app: :gpui, crate: :gpui_native

  def start_runtime(), do: :erlang.nif_error(:nif_not_loaded)
  def open_window(_runtime, _window), do: :erlang.nif_error(:nif_not_loaded)
  def drain_events(_runtime), do: :erlang.nif_error(:nif_not_loaded)
  def validate_tree(_tree), do: :erlang.nif_error(:nif_not_loaded)
end
