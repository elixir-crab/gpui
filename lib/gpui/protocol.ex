defmodule GPUI.Protocol do
  @moduledoc """
  Small Erlang External Term Format helpers for internal protocol payloads.

  Remote transports and tests can use this when they need raw ETF payloads;
  native rendering goes through the Rustler NIF backend directly.
  """

  @type message :: map()

  @spec encode(message()) :: binary()
  def encode(message) when is_map(message) do
    :erlang.term_to_binary(message)
  end

  @spec decode(binary()) :: message()
  def decode(payload) when is_binary(payload) do
    :erlang.binary_to_term(payload, [:safe])
  end

  @spec command(atom(), map()) :: message()
  def command(op, payload \\ %{}) when is_atom(op) and is_map(payload) do
    %{op: op, payload: payload}
  end
end
