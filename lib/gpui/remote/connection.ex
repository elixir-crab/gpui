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

    case start(
           server: self(),
           connection_id: connection_id,
           request_limit: state.connection_request_limit
         ) do
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
       connection_id: Keyword.fetch!(opts, :connection_id),
       request_limit: Keyword.fetch!(opts, :request_limit),
       delegates: %{}
     }}
  end

  @impl GenServer
  def handle_call({:delegate_complete, token, reply}, _task_from, state) do
    case Map.fetch(state.delegates, token) do
      {:ok, {_task, _task_monitor, _caller_monitor, nil}} -> :ok
      {:ok, {_task, _task_monitor, _caller_monitor, from}} -> GenServer.reply(from, reply)
      :error -> :ok
    end

    {:reply, :ok, remove_delegate(state, token)}
  end

  def handle_call({:dispatch, request}, from, state) do
    if map_size(state.delegates) >= state.request_limit do
      {:reply, {:error, :overloaded}, state}
    else
      case GenServer.call(state.server, {:dispatch, state.connection_id, request}, :infinity) do
        {:delegate, route, session_request} ->
          delegate_request(state, from, route, session_request)

        reply ->
          {:reply, reply, state}
      end
    end
  end

  @impl GenServer
  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    match =
      Enum.find_value(state.delegates, fn {token, {_task, task_monitor, caller_monitor, _from}} ->
        cond do
          task_monitor == monitor -> {token, :task}
          not is_nil(caller_monitor) and caller_monitor == monitor -> {token, :caller}
          true -> nil
        end
      end)

    {:noreply, handle_delegate_down(state, match)}
  end

  @impl GenServer
  def terminate(_reason, state) do
    Enum.each(state.delegates, fn {_token, {task, _task_monitor, _caller_monitor, _from}} ->
      Process.exit(task, :kill)
    end)
  end

  defp delegate_request(state, from, route, request) do
    owner = self()
    token = make_ref()

    {:ok, task} =
      Task.start(fn ->
        reply = GPUI.Remote.Session.call(route, request)
        GenServer.call(owner, {:delegate_complete, token, reply}, :infinity)
      end)

    task_monitor = Process.monitor(task)
    caller_monitor = Process.monitor(elem(from, 0))

    {:noreply, put_in(state.delegates[token], {task, task_monitor, caller_monitor, from})}
  end

  defp remove_delegate(state, nil), do: state

  defp remove_delegate(state, token) do
    case Map.pop(state.delegates, token) do
      {nil, _delegates} ->
        state

      {{_task, task_monitor, caller_monitor, _from}, delegates} ->
        Process.demonitor(task_monitor, [:flush])
        if caller_monitor, do: Process.demonitor(caller_monitor, [:flush])
        %{state | delegates: delegates}
    end
  end

  defp handle_delegate_down(state, nil), do: state

  defp handle_delegate_down(state, {token, :task}) do
    {_task, _task_monitor, _caller_monitor, from} = Map.fetch!(state.delegates, token)

    if from do
      GenServer.reply(from, {:error, {:session_unavailable, :delegate_failed}})
    end

    remove_delegate(state, token)
  end

  defp handle_delegate_down(state, {token, :caller}) do
    {task, task_monitor, _caller_monitor, _from} = Map.fetch!(state.delegates, token)
    put_in(state.delegates[token], {task, task_monitor, nil, nil})
  end
end
