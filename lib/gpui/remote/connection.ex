defmodule GPUI.Remote.Connection do
  @moduledoc "Owns accepted remote sockets, request delegates, and connection limits."

  use GenServer

  alias GPUI.Remote.ConnectionTree
  alias GPUI.Remote.Supervision
  alias GPUI.Remote.Transport.TCP

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def port(%{listener: listener}), do: TCP.port(listener)

  def configure(owner, task_supervisor) do
    GenServer.call(owner, {:configure, task_supervisor})
  end

  def accept(state, socket) do
    connection_id = System.unique_integer([:positive])

    child_spec = %{
      id: {ConnectionTree, connection_id},
      start:
        {ConnectionTree, :start_link,
         [
           [
             server: self(),
             connection_id: connection_id,
             request_limit: state.connection_request_limit
           ]
         ]},
      restart: :temporary,
      type: :supervisor
    }

    case DynamicSupervisor.start_child(state.connection_supervisor, child_spec) do
      {:ok, tree} ->
        finish_accept(state, tree, socket, connection_id)

      {:error, _reason} ->
        TCP.close(socket)
        state
    end
  end

  defp finish_accept(state, tree, socket, connection_id) do
    with {:ok, owner} <- Supervision.child(tree, :owner, :connection_unavailable),
         {:ok, task_supervisor} <- Supervision.child(tree, :tasks, :connection_unavailable),
         :ok <- configure(owner, task_supervisor),
         {:ok, _rpc} <- ConnectionTree.start_rpc(tree, owner, socket) do
      Process.monitor(tree)
      put_in(state.connections[tree], %{owner: owner, id: connection_id})
    else
      {:error, _reason} ->
        Supervisor.stop(tree)
        TCP.close(socket)
        state
    end
  end

  def remove(state, pid) do
    {connection, connections} = Map.pop(state.connections, pid)
    state = %{state | connections: connections}

    if connection do
      update_in(state.negotiated_connections, &Map.delete(&1, connection.id))
    else
      state
    end
  end

  @impl GenServer
  def init(opts) do
    {:ok,
     %{
       server: Keyword.fetch!(opts, :server),
       connection_id: Keyword.fetch!(opts, :connection_id),
       request_limit: Keyword.fetch!(opts, :request_limit),
       task_supervisor: nil,
       delegates: %{}
     }}
  end

  @impl GenServer
  def handle_call({:configure, task_supervisor}, _from, %{task_supervisor: nil} = state) do
    {:reply, :ok, %{state | task_supervisor: task_supervisor}}
  end

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

  defp delegate_request(state, from, route, request) do
    owner = self()
    token = make_ref()

    case Task.Supervisor.start_child(state.task_supervisor, fn ->
           reply = GPUI.Remote.Session.call(route, request)
           GenServer.call(owner, {:delegate_complete, token, reply}, :infinity)
         end) do
      {:ok, task} ->
        task_monitor = Process.monitor(task)
        caller_monitor = Process.monitor(elem(from, 0))

        {:noreply, put_in(state.delegates[token], {task, task_monitor, caller_monitor, from})}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
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
