defmodule GPUI.Native do
  @moduledoc false

  use Rustler, otp_app: :gpui, crate: :gpui_nif, path: "native/gpui"

  def start_runtime, do: :erlang.nif_error(:nif_not_loaded)
  def open_window(_runtime, _window), do: :erlang.nif_error(:nif_not_loaded)
  def update_window(_runtime, _window_id, _tree), do: :erlang.nif_error(:nif_not_loaded)
  def put_resource(_runtime, _resource_id, _resource), do: :erlang.nif_error(:nif_not_loaded)
  def drop_resource(_runtime, _resource_id), do: :erlang.nif_error(:nif_not_loaded)
  def drain_events(_runtime), do: :erlang.nif_error(:nif_not_loaded)
  def inject_event(_runtime, _event), do: :erlang.nif_error(:nif_not_loaded)
  def validate_tree(_tree), do: :erlang.nif_error(:nif_not_loaded)
end
