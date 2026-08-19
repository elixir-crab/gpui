defmodule GPUI.Remote.Protocol do
  @moduledoc """
  Transport-independent contract between a remote application session and display.

  SafeRPC owns request mechanics and term safety. This module defines only the
  versioned GPUI operations and capability negotiation.
  """

  @version 2
  @capability :gpui_app
  @required_peer_capabilities [:display_v1]
  @server_capabilities [
    :app_server,
    :safe_rpc,
    :snapshot_v2,
    :window_topology_v1,
    :external_path_transfer_v1
  ]
  @display_capabilities [:display_v1, :external_path_transfer_v1]
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
      Map.merge(
        %{role: :display_client, version: @version, capabilities: @display_capabilities},
        payload
      )

    message(:hello, payload)
  end

  def negotiate(payload) when is_map(payload) do
    GPUI.Remote.ProtocolNegotiation.negotiate(
      payload,
      @version,
      @required_peer_capabilities,
      @server_capabilities
    )
  end

  @spec transfer_event?(term()) :: boolean()
  def transfer_event?(%{type: type}), do: GPUI.Transfer.Event.type?(type)
  def transfer_event?(_event), do: false

  @spec validate_transfer_event(map()) :: {:ok, map()} | {:error, term()}
  def validate_transfer_event(%{type: type, value: value} = event) do
    with true <- GPUI.Transfer.Event.type?(type),
         {:ok, value} <- GPUI.Transfer.Event.normalize(type, value) do
      {:ok, Map.put(event, :value, value)}
    else
      false -> {:error, {:invalid_transfer_event, :type}}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_transfer_event(_event), do: {:error, {:invalid_transfer_event, :shape}}

  def mount(args \\ %{}) when is_map(args), do: message(:mount, args)
  def resume_session(session_id), do: message(:resume_session, %{session_id: session_id})
  def event(event) when is_map(event), do: message(:event, event)
  def snapshot, do: message(:snapshot, %{})

  defp message(op, payload), do: %{op: op, payload: payload}
end
