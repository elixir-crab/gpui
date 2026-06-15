defmodule GPUIProtocolEnvelopeTest do
  use ExUnit.Case, async: true

  alias GPUI.Protocol.Envelope

  test "builds request envelopes" do
    assert %{
             gpui: 1,
             id: id,
             kind: :request,
             op: :hello,
             payload: %{role: :display_client},
             meta: %{}
           } = Envelope.request(:hello, %{role: :display_client})

    assert is_integer(id) and id > 0
  end

  test "builds events without correlation ids by default" do
    assert %{gpui: 1, id: nil, kind: :event, op: :event, payload: %{type: :click}} =
             Envelope.event(:event, %{type: :click})
  end

  test "builds ok and error responses" do
    assert %{kind: :response, id: 12, status: :ok, payload: %{pong: true}} =
             Envelope.ok(12, %{pong: true})

    assert %{kind: :response, id: 12, status: :error, reason: :unknown_window} =
             Envelope.error(12, :unknown_window)
  end

  test "round-trips through ETF" do
    envelope = Envelope.request(:open_window, %{id: 1}, id: 42)
    assert ^envelope = envelope |> Envelope.encode() |> Envelope.decode()
  end

  test "rejects invalid envelopes" do
    assert_raise ArgumentError, ~r/invalid GPUI envelope/, fn ->
      Envelope.validate!(%{gpui: 1, kind: :request, op: :hello, payload: %{}})
    end
  end
end
