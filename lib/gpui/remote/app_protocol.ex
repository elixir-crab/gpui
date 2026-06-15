defmodule GPUI.Remote.AppProtocol do
  @moduledoc """
  Zed-style remote app operation contract.

  This is the inverse of `GPUI.Remote.DisplayProtocol`: a local display client
  can talk to a remote OTP app server that owns application/runtime state.
  SafeRPC owns the RPC mechanics; this module only defines GPUI app ops.
  """

  @version 1
  @capability :gpui_app
  @required_peer_capabilities [:display_v1]
  @server_capabilities [:app_server, :safe_rpc, :snapshot_v1]
  @ops [:hello, :mount, :resume_session, :event, :snapshot]

  @type op :: :hello | :mount | :resume_session | :event | :snapshot
  @type message :: %{op: op(), payload: map()}

  def version, do: @version
  def capability, do: @capability
  def required_peer_capabilities, do: @required_peer_capabilities
  def server_capabilities, do: @server_capabilities
  def ops, do: @ops
  def known_op?(op), do: op in @ops

  def hello(payload \\ %{}) when is_map(payload) do
    payload =
      Map.merge(%{role: :display_client, version: @version, capabilities: [:display_v1]}, payload)

    message(:hello, payload)
  end

  def negotiate(%{version: version}) when version != @version do
    {:error, {:incompatible_version, %{expected: @version, got: version}}}
  end

  def negotiate(payload) when is_map(payload) do
    capabilities = Map.get(payload, :capabilities, [])

    case @required_peer_capabilities -- capabilities do
      [] -> {:ok, %{version: @version, capabilities: @server_capabilities}}
      missing -> {:error, {:missing_capabilities, missing}}
    end
  end

  def mount(args \\ %{}) when is_map(args), do: message(:mount, args)
  def resume_session(session_id), do: message(:resume_session, %{session_id: session_id})
  def event(event) when is_map(event), do: message(:event, event)
  def snapshot, do: message(:snapshot, %{})

  defp message(op, payload), do: %{op: op, payload: payload}
end
