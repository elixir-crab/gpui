defmodule GPUI.Remote.Transport do
  @moduledoc """
  Generic framed transport helpers for GPUI remote messages.

  The wire format is:

      uint32 big-endian length
      ETF payload

  The payload is normally a `GPUI.Protocol.Envelope` map, but this module only
  requires an Elixir term that `GPUI.Protocol` can encode/decode.
  """

  alias GPUI.Remote.Transport.TCP
  alias GPUI.Remote.Transport.TCP.Connection

  @type connection :: Connection.t()

  @spec send(connection(), map()) :: :ok | {:error, term()}
  def send(%Connection{} = conn, message) when is_map(message) do
    payload = GPUI.Protocol.encode(message)
    frame = <<byte_size(payload)::32-big, payload::binary>>
    TCP.send(conn, frame)
  end

  @spec recv(connection(), timeout()) :: {:ok, map()} | {:error, term()}
  def recv(%Connection{} = conn, timeout \\ 5_000) do
    with {:ok, <<size::32-big>>} <- TCP.recv(conn, 4, timeout),
         {:ok, payload} <- TCP.recv(conn, size, timeout) do
      {:ok, GPUI.Protocol.decode(payload)}
    end
  end

  @spec close(connection()) :: :ok
  def close(%Connection{} = conn), do: TCP.close(conn)
end
