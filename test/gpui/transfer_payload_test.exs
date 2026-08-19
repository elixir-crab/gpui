defmodule GPUI.Transfer.PayloadTest do
  use ExUnit.Case, async: true

  alias GPUI.Transfer.Payload

  test "normalizes transfer event payloads into the public value type" do
    event =
      GPUI.Event.normalize(%{
        type: :drop,
        value: %{
          session_id: 17,
          target_id: "drop-zone",
          x: 10.0,
          y: 20.0,
          coordinate_space: "window_native_pixels",
          payload: %{text: nil, external_paths: ["/display/tmp/a"]}
        }
      })

    assert %Payload{external_paths: ["/display/tmp/a"]} = event.value.payload
    assert event.value.session_id == 17
    assert event.value.target_id == "drop-zone"
  end

  test "builds bounded text and display-machine path facts" do
    payload = Payload.new(text: "hello", external_paths: ["/tmp/a", "/tmp/a", "/tmp/b"])

    assert Payload.to_payload(payload) == %{
             text: "hello",
             external_paths: ["/tmp/a", "/tmp/b"]
           }
  end

  test "accepts each independent boundary" do
    assert %Payload{} = Payload.new(text: :binary.copy("x", 1_048_576))
    assert %Payload{} = Payload.new(external_paths: List.duplicate("/tmp/a", 64))
    assert %Payload{} = Payload.new(external_paths: [:binary.copy("x", 4_096)])
  end

  test "rejects unbounded or malformed text and paths" do
    assert_raise ArgumentError, ~r/no larger than 1 MiB/, fn ->
      Payload.new(text: :binary.copy("x", 1_048_577))
    end

    assert_raise ArgumentError, ~r/at most 64 external paths/, fn ->
      Payload.new(external_paths: List.duplicate("/tmp/a", 65))
    end

    assert_raise ArgumentError, ~r/no larger than 4096 bytes/, fn ->
      Payload.new(external_paths: [:binary.copy("x", 4_097)])
    end

    assert_raise ArgumentError, ~r/non-empty UTF-8 strings/, fn ->
      Payload.new(external_paths: [""])
    end

    assert_raise ArgumentError, ~r/must be a list/, fn ->
      Payload.new(external_paths: "/tmp/a")
    end
  end
end
