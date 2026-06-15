defmodule GPUI.Host do
  @moduledoc """
  Port wrapper for the Rust GPUI host executable.
  """

  @spec start_link(keyword()) :: port()
  def start_link(opts \\ []) do
    executable = Keyword.get_lazy(opts, :executable, &default_executable/0)

    Port.open({:spawn_executable, executable}, [
      :binary,
      :exit_status,
      {:packet, 4},
      {:args, Keyword.get(opts, :args, [])}
    ])
  end

  @spec command(port(), map()) :: true
  def command(port, message) when is_port(port) and is_map(message) do
    Port.command(port, GPUI.Protocol.encode(message))
  end

  @spec request(port(), map(), timeout()) :: map()
  def request(port, message, timeout \\ 5_000) when is_port(port) and is_map(message) do
    command(port, message)

    receive do
      {^port, {:data, payload}} -> GPUI.Protocol.decode(payload)
      {^port, {:exit_status, status}} -> exit({:gpui_host_exit, status})
    after
      timeout -> exit(:gpui_host_timeout)
    end
  end

  @spec default_executable() :: String.t()
  def default_executable do
    Path.expand("../../native/gpui_host/target/release/gpui_host", __DIR__)
  end
end
