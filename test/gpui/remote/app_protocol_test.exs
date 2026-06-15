defmodule GPUI.Remote.AppProtocolTest do
  use ExUnit.Case, async: true

  alias GPUI.Remote.AppProtocol

  test "defines app capability and operations" do
    assert AppProtocol.capability() == :gpui_app
    assert AppProtocol.ops() == [:hello, :mount, :resume_session, :event, :snapshot]
    assert AppProtocol.known_op?(:event)
    refute AppProtocol.known_op?(:open_window)
  end

  test "builds transport-independent app operation payloads" do
    assert %{op: :hello, payload: %{role: :display_client}} =
             AppProtocol.hello(%{role: :display_client})

    assert %{op: :mount, payload: %{args: []}} = AppProtocol.mount(%{args: []})

    assert %{op: :resume_session, payload: %{session_id: "abc"}} =
             AppProtocol.resume_session("abc")

    assert %{op: :event, payload: %{type: :click}} = AppProtocol.event(%{type: :click})
    assert %{op: :snapshot, payload: %{}} = AppProtocol.snapshot()
  end
end
