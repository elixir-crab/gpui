defmodule GPUI.Remote.ServerConnection do
  @moduledoc false

  alias GPUI.Remote.Acceptor
  alias GPUI.Remote.ConnectionOwner
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Server.Connection

  @spec port(map()) :: {:ok, :inet.port_number()} | {:error, term()}
  def port(%{listener: listener}), do: TCP.port(listener)

  @spec accept(map(), term()) :: map()
  def accept(state, socket) do
    Acceptor.start(state.listener)

    connection_id = System.unique_integer([:positive])

    {:ok, owner} =
      ConnectionOwner.start_link(server: self(), connection_id: connection_id)

    child_spec = %{
      id: {Connection, connection_id},
      start:
        {Connection, :start_link,
         [[owner: owner, transport: SafeRPCTCP, socket: socket, recv_timeout: 5_000]]},
      restart: :temporary
    }

    {:ok, pid} = DynamicSupervisor.start_child(state.connection_supervisor, child_spec)
    Process.monitor(pid)
    put_in(state.connections[pid], %{socket: socket, owner: owner, id: connection_id})
  end

  @spec remove(map(), pid()) :: map()
  def remove(state, pid) do
    {connection, connections} = Map.pop(state.connections, pid)

    if connection && Process.alive?(connection.owner) do
      GenServer.stop(connection.owner)
    end

    state = %{state | connections: connections}

    if connection do
      update_in(state.negotiated_connections, &MapSet.delete(&1, connection.id))
    else
      state
    end
  end
end
