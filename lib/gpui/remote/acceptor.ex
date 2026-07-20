defmodule GPUI.Remote.Acceptor do
  @moduledoc false

  alias GPUI.Remote.Transport.TCP

  @spec start(TCP.listener()) :: {:ok, pid()}
  def start(listener) do
    owner = self()

    Task.start(fn ->
      case TCP.accept(listener, :infinity) do
        {:ok, socket} ->
          transfer_socket(socket, owner)

        {:error, reason} ->
          send(owner, {:gpui_remote_accept_error, reason})
      end
    end)
  end

  defp transfer_socket(socket, owner) do
    case TCP.controlling_process(socket, owner) do
      :ok ->
        send(owner, {:gpui_remote_accepted, socket})

      {:error, reason} ->
        TCP.close(socket)
        send(owner, {:gpui_remote_accept_error, reason})
    end
  end
end
