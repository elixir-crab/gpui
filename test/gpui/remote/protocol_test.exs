defmodule GPUI.Remote.ProtocolTest do
  use ExUnit.Case, async: true

  alias GPUI.Remote.Protocol

  test "defines app capability and operations" do
    assert Protocol.capability() == :gpui_app
    assert Protocol.ops() == [:hello, :mount, :resume_session, :event, :snapshot]
    assert Protocol.known_op?(:event)
    refute Protocol.known_op?(:open_window)
  end

  test "builds transport-independent messages" do
    assert %{op: :hello, payload: %{role: :display_client, capabilities: capabilities}} =
             Protocol.hello(%{role: :display_client})

    assert :external_path_transfer_v1 in capabilities
    assert :clipboard_text_v1 in capabilities

    assert %{op: :mount, payload: %{args: []}} = Protocol.mount(%{args: []})

    assert %{op: :resume_session, payload: %{session_id: "abc"}} =
             Protocol.resume_session("abc")

    assert %{op: :event, payload: %{type: :click}} = Protocol.event(%{type: :click})
    assert %{op: :snapshot, payload: %{}} = Protocol.snapshot()
  end

  test "validates bounded clipboard events" do
    assert {:ok, %{value: %GPUI.Transfer.Payload{text: "paste"}}} =
             Protocol.validate_clipboard_event(%{
               type: :clipboard,
               value: %{text: "paste", external_paths: []}
             })

    assert {:error, {:invalid_clipboard_event, _reason}} =
             Protocol.validate_clipboard_event(%{
               type: :clipboard,
               value: %{text: :binary.copy("x", 1_048_577), external_paths: []}
             })
  end

  test "negotiates protocol version and capabilities" do
    assert {:ok, %{version: 2, capabilities: capabilities}} =
             Protocol.negotiate(%{version: 2, capabilities: [:display_v1]})

    assert :app_server in capabilities
    assert :window_topology_v1 in capabilities
    assert :external_path_transfer_v1 in capabilities
    assert :clipboard_text_v1 in capabilities

    assert {:error, {:incompatible_version, %{expected: 2, got: 1}}} =
             Protocol.negotiate(%{version: 1, capabilities: [:display_v1]})

    assert {:error, {:missing_capabilities, [:display_v1]}} =
             Protocol.negotiate(%{version: 2, capabilities: []})

    assert {:error, {:incompatible_version, %{expected: 2, got: nil}}} =
             Protocol.negotiate(%{capabilities: [:display_v1]})
  end
end
