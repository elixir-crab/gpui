defmodule GPUI.Remote.RequestGate do
  @moduledoc false

  use GenServer

  def start_link(limit), do: GenServer.start_link(__MODULE__, limit)

  def checkout(gate) do
    GenServer.call(gate, :checkout)
  catch
    :exit, reason -> {:error, {:session_unavailable, reason}}
  end

  def checkin(gate, token) do
    GenServer.call(gate, {:checkin, token})
  catch
    :exit, _reason -> :ok
  end

  @impl GenServer
  def init(limit) when is_integer(limit) and limit > 0 do
    {:ok, %{limit: limit, active: %{}, monitors: %{}}}
  end

  @impl GenServer
  def handle_call(:checkout, {caller, _tag}, state) do
    if map_size(state.active) >= state.limit do
      {:reply, {:error, :overloaded}, state}
    else
      token = make_ref()
      monitor = Process.monitor(caller)

      state = %{
        state
        | active: Map.put(state.active, token, monitor),
          monitors: Map.put(state.monitors, monitor, token)
      }

      {:reply, {:ok, token}, state}
    end
  end

  def handle_call({:checkin, token}, _from, state) do
    {:reply, :ok, remove_token(state, token)}
  end

  @impl GenServer
  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    case Map.fetch(state.monitors, monitor) do
      {:ok, token} -> {:noreply, remove_token(state, token)}
      :error -> {:noreply, state}
    end
  end

  defp remove_token(state, token) do
    case Map.pop(state.active, token) do
      {nil, _active} ->
        state

      {monitor, active} ->
        Process.demonitor(monitor, [:flush])
        %{state | active: active, monitors: Map.delete(state.monitors, monitor)}
    end
  end
end
