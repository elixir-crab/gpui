defmodule GPUI.Runtime.Subscriptions do
  @moduledoc "Subscription-map helpers for publishing synchronized runtime updates."

  @spec subscribe(%{pid() => reference()}, pid()) :: %{pid() => reference()}
  def subscribe(subscribers, pid) do
    if Map.has_key?(subscribers, pid) do
      subscribers
    else
      Map.put(subscribers, pid, Process.monitor(pid))
    end
  end

  @spec unsubscribe(%{pid() => reference()}, pid()) :: %{pid() => reference()}
  def unsubscribe(subscribers, pid) do
    {monitor, subscribers} = Map.pop(subscribers, pid)
    if monitor, do: Process.demonitor(monitor, [:flush])
    subscribers
  end

  @spec remove_down(%{pid() => reference()}, pid(), reference()) :: %{pid() => reference()}
  def remove_down(subscribers, pid, monitor) do
    case Map.get(subscribers, pid) do
      ^monitor -> Map.delete(subscribers, pid)
      _other -> subscribers
    end
  end

  @spec publish_update(map(), pid(), [map()], GPUI.Snapshot.t()) :: map()
  def publish_update(state, source, events, snapshot) do
    revision = state.revision + 1
    update = %GPUI.Runtime.Update{revision: revision, events: events, snapshot: snapshot}

    Enum.each(state.subscribers, fn {pid, _monitor} ->
      send(pid, {:gpui, source, update})
    end)

    %{state | revision: revision}
  end
end
