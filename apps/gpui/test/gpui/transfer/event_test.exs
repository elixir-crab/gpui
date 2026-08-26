defmodule GPUI.Transfer.EventTest do
  use ExUnit.Case, async: true

  alias GPUI.Transfer.Event
  alias GPUI.Transfer.Payload

  @base %{
    session_id: 7,
    target_id: "drop-zone",
    x: 12.5,
    y: 24,
    coordinate_space: "window_native_pixels"
  }

  test "normalizes native wire maps into public values" do
    assert {:ok, value} =
             Event.normalize(
               :drag_enter,
               Map.put(@base, :payload, %{text: nil, external_paths: ["/display/tmp/a"]})
             )

    assert %Event{
             session_id: 7,
             target_id: "drop-zone",
             position: {12.5, 24},
             coordinate_space: :window_native_pixels,
             payload: %Payload{external_paths: ["/display/tmp/a"]}
           } = value
  end

  test "accepts and validates canonical public values" do
    value = %Event{
      session_id: 7,
      target_id: "drop-zone",
      position: {12.5, 24},
      coordinate_space: :window_native_pixels,
      payload: nil
    }

    assert {:ok, ^value} = Event.normalize(:drag_move, value)
  end

  test "serializes public values for native and remote transport" do
    value = %Event{
      session_id: 7,
      target_id: "drop-zone",
      position: {12.5, 24},
      coordinate_space: :window_native_pixels,
      payload: %Payload{external_paths: ["/display/tmp/a"]}
    }

    assert Event.to_payload(value) == %{
             session_id: 7,
             target_id: "drop-zone",
             x: 12.5,
             y: 24,
             coordinate_space: "window_native_pixels",
             payload: %{text: nil, external_paths: ["/display/tmp/a"]}
           }
  end

  test "enforces payload presence by event phase" do
    assert {:error, {:invalid_transfer_event, :payload_presence}} =
             Event.normalize(:drag_enter, Map.put(@base, :payload, nil))

    assert {:error, {:invalid_transfer_event, :payload_presence}} =
             Event.normalize(
               :drag_move,
               Map.put(@base, :payload, %{text: nil, external_paths: ["/tmp/a"]})
             )

    assert {:ok, %Event{payload: nil}} =
             Event.normalize(:drag_leave, Map.put(@base, :payload, nil))
  end

  test "rejects malformed identity and coordinates" do
    assert {:error, {:invalid_transfer_event, :session_id}} =
             Event.normalize(:drop, Map.merge(@base, %{session_id: 0, payload: %{}}))

    assert {:error, {:invalid_transfer_event, :target_id}} =
             Event.normalize(:drop, Map.merge(@base, %{target_id: "", payload: %{}}))

    assert {:error, {:invalid_transfer_event, :x}} =
             Event.normalize(:drop, Map.merge(@base, %{x: :nan, payload: %{}}))

    assert {:error, {:invalid_transfer_event, :coordinate_space}} =
             Event.normalize(
               :drop,
               Map.merge(@base, %{coordinate_space: "screen_pixels", payload: %{}})
             )
  end
end
