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
    assert %{op: :hello, payload: %{role: :display_client}} =
             Protocol.hello(%{role: :display_client})

    assert %{op: :mount, payload: %{args: []}} = Protocol.mount(%{args: []})

    assert %{op: :resume_session, payload: %{session_id: "abc"}} =
             Protocol.resume_session("abc")

    assert %{op: :event, payload: %{type: :click}} = Protocol.event(%{type: :click})
    assert %{op: :snapshot, payload: %{}} = Protocol.snapshot()
  end

  test "negotiates protocol version and capabilities" do
    assert {:ok, %{version: 2, capabilities: capabilities}} =
             Protocol.negotiate(%{version: 2, capabilities: [:display_v1]})

    assert :app_server in capabilities

    assert {:error, {:incompatible_version, %{expected: 2, got: 1}}} =
             Protocol.negotiate(%{version: 1, capabilities: [:display_v1]})

    assert {:error, {:missing_capabilities, [:display_v1]}} =
             Protocol.negotiate(%{version: 2, capabilities: []})
  end
end
