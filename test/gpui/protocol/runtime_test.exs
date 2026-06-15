defmodule GPUIProtocolRuntimeTest do
  use ExUnit.Case, async: true

  alias GPUI.Protocol.Runtime, as: RuntimeProtocol

  test "builds versioned open_window messages" do
    window = %{id: 1, title: "Remote", root: %{tree: %{type: :div}}}

    assert %{version: 1, op: :open_window, payload: ^window} = RuntimeProtocol.open_window(window)
  end

  test "round-trips through ETF" do
    messages = [
      RuntimeProtocol.open_window(%{id: 1, title: "Remote"}),
      RuntimeProtocol.update_window(1, %{type: :div, attrs: %{}, children: []}),
      RuntimeProtocol.event(%{type: :click, window_id: 1, event: "inc"}),
      RuntimeProtocol.drain_events()
    ]

    for message <- messages do
      assert ^message = message |> RuntimeProtocol.encode() |> RuntimeProtocol.decode()
    end
  end

  test "rejects invalid messages" do
    assert_raise ArgumentError, ~r/invalid GPUI runtime protocol message/, fn ->
      RuntimeProtocol.decode(:erlang.term_to_binary(%{op: :event, payload: %{}}))
    end
  end
end
