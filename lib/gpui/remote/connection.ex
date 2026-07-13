defmodule GPUI.Remote.Connection do
  @moduledoc false

  use GenServer

  alias GPUI.Remote.Acceptor
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Server.Connection, as: RPCConnection

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def port(%{listener: listener}), do: TCP.port(listener)

  def accept(state, socket) do
    Acceptor.start(state.listener)
    connection_id = System.unique_integer([:positive])

    {:ok, owner} = start_link(server: self(), connection_id: connection_id)

    child_spec = %{
      id: {RPCConnection, connection_id},
      start:
        {RPCConnection, :start_link,
         [[owner: owner, transport: TCP, socket: socket, recv_timeout: 5_000]]},
      restart: :temporary
    }

    {:ok, pid} = DynamicSupervisor.start_child(state.connection_supervisor, child_spec)
    Process.monitor(pid)
    put_in(state.connections[pid], %{owner: owner, id: connection_id})
  end

  def remove(state, pid) do
    {connection, connections} = Map.pop(state.connections, pid)

    if connection && Process.alive?(connection.owner), do: GenServer.stop(connection.owner)

    state = %{state | connections: connections}

    if connection do
      update_in(state.negotiated_connections, &MapSet.delete(&1, connection.id))
    else
      state
    end
  end

  @impl GenServer
  def init(opts) do
    {:ok,
     %{
       server: Keyword.fetch!(opts, :server),
       connection_id: Keyword.fetch!(opts, :connection_id)
     }}
  end

  @impl GenServer
  def handle_call({:dispatch, request}, _from, state) do
    reply = GenServer.call(state.server, {:dispatch, state.connection_id, request}, :infinity)
    {:reply, reply, state}
  end
end
