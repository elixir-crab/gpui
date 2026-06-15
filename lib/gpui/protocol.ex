defmodule GPUI.Protocol do
  @moduledoc """
  Erlang External Term Format protocol shared by the OTP runtime and Rust host.

  Port communication uses `{:packet, 4}` framing, so `encode/1` returns only the
  ETF payload. Standalone length-prefixed framing can be added at the transport
  layer if we need to talk over raw stdio without Erlang Port packet mode.
  """

  @type message :: map()

  @spec encode(message()) :: binary()
  def encode(message) when is_map(message) do
    :erlang.term_to_binary(message)
  end

  @spec decode(binary()) :: message()
  def decode(payload) when is_binary(payload) do
    :erlang.binary_to_term(payload)
  end

  @spec command(atom(), map()) :: message()
  def command(op, payload \\ %{}) when is_atom(op) and is_map(payload) do
    %{op: op, payload: payload}
  end
end
