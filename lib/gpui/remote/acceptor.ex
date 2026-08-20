defmodule GPUI.Remote.Acceptor do
  @moduledoc "Accept loop that transfers remote sockets into supervised connection trees."

  use GenServer

  alias GPUI.Remote.Transport.TCP

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    {:ok,
     %{
       listener: Keyword.fetch!(opts, :listener),
       owner: Keyword.fetch!(opts, :owner)
     }, {:continue, :accept}}
  end

  @impl GenServer
  def handle_continue(:accept, state) do
    case TCP.accept(state.listener, :infinity) do
      {:ok, socket} ->
        transfer_socket(socket, state.owner)
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        send(state.owner, {:gpui_remote_accept_error, reason})
        {:stop, :normal, state}
    end
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
