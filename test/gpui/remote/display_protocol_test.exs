defmodule GPUI.Remote.DisplayProtocolTest do
  use ExUnit.Case, async: true

  alias GPUI.Remote.DisplayProtocol

  test "defines display capability and operations" do
    assert DisplayProtocol.capability() == :gpui_display

    assert DisplayProtocol.ops() == [
             :hello,
             :ping,
             :resume_session,
             :open_window,
             :update_window,
             :put_resource,
             :drop_resource,
             :drain_events,
             :event
           ]

    assert DisplayProtocol.known_op?(:open_window)
    refute DisplayProtocol.known_op?(:unknown)
  end

  test "builds transport-independent operation payloads" do
    window = %{id: 1, title: "Counter"}

    assert %{op: :hello, payload: %{role: :runtime}} = DisplayProtocol.hello(%{role: :runtime})
    assert %{op: :ping, payload: %{}} = DisplayProtocol.ping()

    assert %{op: :resume_session, payload: %{session_id: "abc"}} =
             DisplayProtocol.resume_session("abc")

    assert %{op: :open_window, payload: ^window} = DisplayProtocol.open_window(window)

    assert %{op: :update_window, payload: %{window_id: 1, tree: %{type: :div}}} =
             DisplayProtocol.update_window(1, %{type: :div})

    assert %{op: :put_resource, payload: %{id: "logo", resource: %{type: :raster}}} =
             DisplayProtocol.put_resource("logo", %{type: :raster})

    assert %{op: :drop_resource, payload: %{id: "logo"}} = DisplayProtocol.drop_resource("logo")

    assert %{op: :event, payload: %{type: :click}} = DisplayProtocol.event(%{type: :click})
    assert %{op: :drain_events, payload: %{}} = DisplayProtocol.drain_events()
  end

  test "negotiates protocol version and capabilities" do
    assert {:ok, %{version: 1, capabilities: capabilities}} =
             DisplayProtocol.negotiate(%{version: 1, capabilities: [:runtime_v1]})

    assert :display_server in capabilities

    assert {:error, {:incompatible_version, %{expected: 1, got: 2}}} =
             DisplayProtocol.negotiate(%{version: 2, capabilities: [:runtime_v1]})

    assert {:error, {:missing_capabilities, [:runtime_v1]}} =
             DisplayProtocol.negotiate(%{version: 1, capabilities: []})
  end
end
