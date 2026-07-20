defmodule GPUI.Remote.Connection do
  @moduledoc false

  use GenServer

  alias GPUI.Remote.Acceptor
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Server.Connection, as: RPCConnection

  def start(opts), do: GenServer.start(__MODULE__, opts)

  def port(%{listener: listener}), do: TCP.port(listener)

  def accept(state, socket) do
    Acceptor.start(state.listener)
    connection_id = System.unique_integer([:positive])

    case start(server: self(), connection_id: connection_id) do
      {:ok, owner} ->
        start_rpc_connection(state, socket, connection_id, owner)

      {:error, _reason} ->
        TCP.close(socket)
        state
    end
  end

  def stop_all(%{connections: connections}) do
    Enum.each(connections, fn {_pid, connection} -> stop_owner(connection.owner) end)
  end

  def remove(state, pid) do
    {connection, connections} = Map.pop(state.connections, pid)

    if connection, do: stop_owner(connection.owner)

    state = %{state | connections: connections}

    if connection do
      update_in(state.negotiated_connections, &MapSet.delete(&1, connection.id))
    else
      state
    end
  end

  defp start_rpc_connection(state, socket, connection_id, owner) do
    child_spec = %{
      id: {RPCConnection, connection_id},
      start:
        {RPCConnection, :start_link,
         [[owner: owner, transport: TCP, socket: socket, recv_timeout: 5_000]]},
      restart: :temporary
    }

    case DynamicSupervisor.start_child(state.connection_supervisor, child_spec) do
      {:ok, pid} ->
        Process.monitor(pid)
        put_in(state.connections[pid], %{owner: owner, id: connection_id})

      {:error, _reason} ->
        GenServer.stop(owner)
        TCP.close(socket)
        state
    end
  end

  defp stop_owner(owner) do
    if Process.alive?(owner), do: Process.exit(owner, :shutdown)
    :ok
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
