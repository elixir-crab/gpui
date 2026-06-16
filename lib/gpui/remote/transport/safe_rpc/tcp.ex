defmodule GPUI.Remote.Transport.SafeRPC.TCP do
  @moduledoc """
  SafeRPC transport over GPUI's framed TCP/SSL socket layer.

  SafeRPC owns term safety, request correlation, cancellation, and timeouts.
  This adapter only moves already-encoded SafeRPC binaries over a 4-byte
  big-endian length-prefixed TCP or SSL connection.
  """

  @behaviour SafeRPC.Transport

  alias GPUI.Remote.Transport.TCP

  @impl SafeRPC.Transport
  def connect(opts), do: TCP.connect(opts)

  @impl SafeRPC.Transport
  def listen(opts), do: TCP.listen(opts)

  @impl SafeRPC.Transport
  def accept(listener, timeout), do: TCP.accept(listener, timeout)

  @impl SafeRPC.Transport
  def send(conn, binary, _timeout) when is_binary(binary) do
    frame = <<byte_size(binary)::32-big, binary::binary>>
    TCP.send(conn, frame)
  end

  @impl SafeRPC.Transport
  def recv(conn, timeout) do
    with {:ok, <<size::32-big>>} <- TCP.recv(conn, 4, timeout) do
      TCP.recv(conn, size, timeout)
    end
  end

  @impl SafeRPC.Transport
  def close(socket), do: TCP.close(socket)
end
