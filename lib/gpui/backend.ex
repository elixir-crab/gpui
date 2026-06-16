defmodule GPUI.Backend do
  @moduledoc """
  Boundary between `GPUI.Runtime` and a concrete transport/rendering backend.

  Backends keep runtime state transport-safe: the runtime deals in rendered
  window payloads and normalized event maps, while each backend owns its local
  implementation details such as Rustler resources or SafeRPC/TCP connections.
  """

  @type state :: term()
  @type event :: map() | keyword() | String.t()

  @callback init(keyword()) :: {:ok, state()} | {:error, term()}
  @callback open_window(state(), map()) :: :ok | {:error, term()}
  @callback update_window(state(), pos_integer(), map() | nil) :: :ok | {:error, term()}
  @callback put_resource(state(), term(), map()) :: :ok | {:error, term()}
  @callback drop_resource(state(), term()) :: :ok | {:error, term()}
  @callback drain_events(state()) :: {:ok, [event()]} | {:error, term()}
  @callback inject_event(state(), map()) :: {:ok, term()} | {:error, term()}
  @callback handle_info(state(), term()) :: {:ok, event()} | :unhandled

  @spec module_for(:native | :remote_tcp) :: module()
  def module_for(:native), do: GPUI.Backend.Native
  def module_for(:remote_tcp), do: GPUI.Backend.RemoteTCP
end
