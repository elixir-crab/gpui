defmodule GPUI.Remote.DisplayProtocolTest do
  use ExUnit.Case, async: true

  alias GPUI.Remote.DisplayProtocol

  test "defines display capability and operations" do
    assert DisplayProtocol.capability() == :gpui_display

    assert DisplayProtocol.ops() == [
             :hello,
             :resume_session,
             :open_window,
             :update_window,
             :drain_events,
             :event
           ]

    assert DisplayProtocol.known_op?(:open_window)
    refute DisplayProtocol.known_op?(:unknown)
  end

  test "builds transport-independent operation payloads" do
    window = %{id: 1, title: "Counter"}

    assert %{op: :hello, payload: %{role: :runtime}} = DisplayProtocol.hello(%{role: :runtime})

    assert %{op: :resume_session, payload: %{session_id: "abc"}} =
             DisplayProtocol.resume_session("abc")

    assert %{op: :open_window, payload: ^window} = DisplayProtocol.open_window(window)

    assert %{op: :update_window, payload: %{window_id: 1, tree: %{type: :div}}} =
             DisplayProtocol.update_window(1, %{type: :div})

    assert %{op: :event, payload: %{type: :click}} = DisplayProtocol.event(%{type: :click})
    assert %{op: :drain_events, payload: %{}} = DisplayProtocol.drain_events()
  end
end
