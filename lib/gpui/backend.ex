defmodule GPUI.Backend do
  @moduledoc """
  Boundary between `GPUI.Runtime` and a concrete transport/rendering backend.

  Backends keep runtime state transport-safe: the runtime deals in rendered
  window payloads and normalized event maps, while each backend owns its local
  implementation details such as Rustler resources or ports.
  """

  @type state :: term()
  @type event :: map() | keyword() | String.t()

  @callback init(keyword()) :: {:ok, state()} | {:error, term()}
  @callback open_window(state(), map()) :: :ok | {:error, term()}
  @callback update_window(state(), pos_integer(), map() | nil) :: :ok | {:error, term()}
  @callback drain_events(state()) :: {:ok, [event()]} | {:error, term()}
  @callback emit_test_event(state(), map()) :: {:ok, term()} | {:error, term()}
  @callback handle_info(state(), term()) :: {:ok, event()} | :unhandled

  @spec module_for(atom() | module()) :: module()
  def module_for(:data), do: GPUI.Backend.Data
  def module_for(:native), do: GPUI.Backend.Native
  def module_for(:host), do: GPUI.Backend.Host
  def module_for(:remote_loopback), do: GPUI.Backend.RemoteLoopback
  def module_for(:remote_tcp), do: GPUI.Backend.RemoteTCP
  def module_for(module) when is_atom(module), do: module
end
