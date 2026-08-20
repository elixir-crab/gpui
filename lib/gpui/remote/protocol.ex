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
    :external_path_transfer_v1,
    :clipboard_text_v1,
    :file_read_v1
  ]
  @display_capabilities [
    :display_v1,
    :external_path_transfer_v1,
    :clipboard_text_v1,
    :file_read_v1
  ]
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

  @spec clipboard_event?(term()) :: boolean()
  def clipboard_event?(%{type: type}) when type in [:clipboard, :clipboard_write], do: true
  def clipboard_event?(_event), do: false

  @spec validate_clipboard_event(map()) :: {:ok, map()} | {:error, term()}
  def validate_clipboard_event(%{type: type} = event)
      when type in [:clipboard, :clipboard_write] do
    case GPUI.Event.normalize(event) do
      {:ok, event} -> {:ok, event}
      {:error, reason} -> {:error, {:invalid_clipboard_event, reason}}
    end
  end

  def validate_clipboard_event(_event), do: {:error, {:invalid_clipboard_event, :shape}}

  @spec file_read_event?(term()) :: boolean()
  def file_read_event?(%{type: :file_read}), do: true
  def file_read_event?(_event), do: false

  @spec validate_file_read_event(map()) :: {:ok, map()} | {:error, term()}
  def validate_file_read_event(%{type: :file_read} = event) do
    case GPUI.Event.normalize(event) do
      {:ok, event} -> {:ok, event}
      {:error, reason} -> {:error, {:invalid_file_read_event, reason}}
    end
  end

  def validate_file_read_event(_event), do: {:error, {:invalid_file_read_event, :shape}}

  @spec transfer_event?(term()) :: boolean()
  def transfer_event?(%{type: type}), do: GPUI.Transfer.Event.type?(type)
  def transfer_event?(_event), do: false

  @spec validate_transfer_event(map()) :: {:ok, map()} | {:error, term()}
  def validate_transfer_event(%{type: type} = event) do
    if GPUI.Transfer.Event.type?(type) do
      GPUI.Event.normalize(event)
    else
      {:error, {:invalid_transfer_event, :type}}
    end
  end

  def validate_transfer_event(_event), do: {:error, {:invalid_transfer_event, :shape}}

  def mount(args \\ %{}) when is_map(args), do: message(:mount, args)
  def resume_session(session_id), do: message(:resume_session, %{session_id: session_id})
  def event(event) when is_map(event), do: message(:event, event)
  def snapshot, do: message(:snapshot, %{})

  defp message(op, payload), do: %{op: op, payload: payload}
end
