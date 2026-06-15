defmodule GPUI.ProtocolTest do
  use ExUnit.Case, async: true

  test "round trips ETF messages" do
    message = GPUI.Protocol.command(:open_window, %{title: "Hello", size: [500, 500]})

    assert GPUI.Protocol.decode(GPUI.Protocol.encode(message)) == message
  end
end
