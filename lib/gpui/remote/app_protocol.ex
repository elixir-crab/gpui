defmodule GPUI.Remote.AppProtocol do
  @moduledoc """
  Zed-style remote app operation contract.

  This is the inverse of `GPUI.Remote.DisplayProtocol`: a local display client
  can talk to a remote OTP app server that owns application/runtime state.
  SafeRPC owns the RPC mechanics; this module only defines GPUI app ops.
  """

  @capability :gpui_app
  @ops [:hello, :mount, :event, :snapshot]

  @type op :: :hello | :mount | :event | :snapshot
  @type message :: %{op: op(), payload: map()}

  def capability, do: @capability
  def ops, do: @ops
  def known_op?(op), do: op in @ops

  def hello(payload \\ %{role: :display_client, capabilities: [:display_v1]})
      when is_map(payload),
      do: message(:hello, payload)

  def mount(args \\ %{}) when is_map(args), do: message(:mount, args)
  def event(event) when is_map(event), do: message(:event, event)
  def snapshot, do: message(:snapshot, %{})

  defp message(op, payload), do: %{op: op, payload: payload}
end
