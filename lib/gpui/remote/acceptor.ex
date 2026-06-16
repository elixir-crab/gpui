defmodule GPUI.Remote.Acceptor do
  @moduledoc false

  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP
  alias GPUI.Remote.Transport.TCP

  @spec start(TCP.Listener.t()) :: {:ok, pid()}
  def start(listener) do
    owner = self()

    Task.start(fn ->
      case SafeRPCTCP.accept(listener, :infinity) do
        {:ok, socket} ->
          :ok = TCP.controlling_process(socket, owner)
          send(owner, {:gpui_remote_accepted, socket})

        {:error, reason} ->
          send(owner, {:gpui_remote_accept_error, reason})
      end
    end)
  end
end
