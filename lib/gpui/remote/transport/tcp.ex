defmodule GPUI.Remote.Transport.TCP do
  @moduledoc """
  Length-prefixed ETF transport over TCP, with optional SSL.
  """

  @behaviour SafeRPC.Transport

  defmodule Listener do
    @moduledoc false
    defstruct [:socket, :mode]
  end

  defmodule Connection do
    @moduledoc false
    defstruct [:socket, :mode]
  end

  @opaque listener :: %Listener{socket: port() | tuple(), mode: :tcp | :ssl}
  @opaque connection :: %Connection{socket: port() | tuple(), mode: :tcp | :ssl}

  @type listen_option :: {:port, :inet.port_number()} | {:ssl, false | keyword()}
  @type connect_option ::
          {:host, String.t() | charlist()}
          | {:port, :inet.port_number()}
          | {:ssl, false | keyword()}
          | {:timeout, timeout()}

  @impl SafeRPC.Transport
  @spec listen([listen_option()]) :: {:ok, listener()} | {:error, term()}
  def listen(opts \\ []) do
    port = Keyword.get(opts, :port, 0)

    case Keyword.get(opts, :ssl, false) do
      false -> listen_tcp(port)
      ssl_opts when is_list(ssl_opts) -> listen_ssl(port, ssl_opts)
    end
  end

  @impl SafeRPC.Transport
  @spec accept(listener(), timeout()) :: {:ok, connection()} | {:error, term()}
  def accept(listener, timeout \\ :infinity)

  def accept(%Listener{socket: socket, mode: :tcp}, timeout) do
    with {:ok, client} <- :gen_tcp.accept(socket, timeout) do
      {:ok, %Connection{socket: client, mode: :tcp}}
    end
  end

  def accept(%Listener{socket: socket, mode: :ssl}, timeout) do
    with {:ok, client} <- :ssl.transport_accept(socket, timeout),
         {:ok, client} <- ssl_handshake(client) do
      {:ok, %Connection{socket: client, mode: :ssl}}
    end
  end

  @impl SafeRPC.Transport
  @spec connect([connect_option()]) :: {:ok, connection()} | {:error, term()}
  def connect(opts) do
    host = opts |> Keyword.fetch!(:host) |> normalize_host()
    port = Keyword.fetch!(opts, :port)
    timeout = Keyword.get(opts, :timeout, 5_000)

    case Keyword.get(opts, :ssl, false) do
      false -> connect_tcp(host, port, timeout)
      ssl_opts when is_list(ssl_opts) -> connect_ssl(host, port, ssl_opts, timeout)
    end
  end

  @spec port(listener()) :: {:ok, :inet.port_number()} | {:error, term()}
  def port(%Listener{socket: socket, mode: :tcp}) do
    with {:ok, {_addr, port}} <- :inet.sockname(socket), do: {:ok, port}
  end

  def port(%Listener{socket: socket, mode: :ssl}) do
    with {:ok, {_addr, port}} <- :ssl.sockname(socket), do: {:ok, port}
  end

  @impl SafeRPC.Transport
  def send(connection, binary, _timeout) when is_binary(binary) do
    raw_send(connection, <<byte_size(binary)::32-big, binary::binary>>)
  end

  @impl SafeRPC.Transport
  def recv(connection, timeout) do
    with {:ok, <<size::32-big>>} <- raw_recv(connection, 4, timeout) do
      raw_recv(connection, size, timeout)
    end
  end

  @spec controlling_process(connection(), pid()) :: :ok | {:error, term()}
  def controlling_process(%Connection{socket: socket, mode: :tcp}, pid),
    do: :gen_tcp.controlling_process(socket, pid)

  def controlling_process(%Connection{socket: socket, mode: :ssl}, pid),
    do: :ssl.controlling_process(socket, pid)

  @impl SafeRPC.Transport
  @spec close(connection() | listener()) :: :ok
  def close(%Connection{socket: socket, mode: :tcp}), do: :gen_tcp.close(socket)
  def close(%Connection{socket: socket, mode: :ssl}), do: :ssl.close(socket)
  def close(%Listener{socket: socket, mode: :tcp}), do: :gen_tcp.close(socket)
  def close(%Listener{socket: socket, mode: :ssl}), do: :ssl.close(socket)

  defp raw_send(%Connection{socket: socket, mode: :tcp}, frame), do: :gen_tcp.send(socket, frame)
  defp raw_send(%Connection{socket: socket, mode: :ssl}, frame), do: :ssl.send(socket, frame)

  defp raw_recv(%Connection{socket: socket, mode: :tcp}, size, timeout),
    do: :gen_tcp.recv(socket, size, timeout)

  defp raw_recv(%Connection{socket: socket, mode: :ssl}, size, timeout),
    do: :ssl.recv(socket, size, timeout)

  defp ssl_handshake(client), do: :ssl.handshake(client)

  defp listen_tcp(port) do
    opts = [:binary, active: false, packet: :raw, reuseaddr: true, ip: {127, 0, 0, 1}]

    with {:ok, socket} <- :gen_tcp.listen(port, opts) do
      {:ok, %Listener{socket: socket, mode: :tcp}}
    end
  end

  defp listen_ssl(port, ssl_opts) do
    :ok = :ssl.start()
    opts = [:binary, active: false, packet: :raw, reuseaddr: true, ip: {127, 0, 0, 1}] ++ ssl_opts

    with {:ok, socket} <- :ssl.listen(port, opts) do
      {:ok, %Listener{socket: socket, mode: :ssl}}
    end
  end

  defp connect_tcp(host, port, timeout) do
    opts = [:binary, active: false, packet: :raw]

    with {:ok, socket} <- :gen_tcp.connect(host, port, opts, timeout) do
      {:ok, %Connection{socket: socket, mode: :tcp}}
    end
  end

  defp connect_ssl(host, port, ssl_opts, timeout) do
    :ok = :ssl.start()
    opts = [:binary, active: false, packet: :raw] ++ ssl_opts

    with {:ok, socket} <- :ssl.connect(host, port, opts, timeout) do
      {:ok, %Connection{socket: socket, mode: :ssl}}
    end
  end

  defp normalize_host(host) when is_binary(host), do: String.to_charlist(host)
  defp normalize_host(host) when is_list(host), do: host
end
