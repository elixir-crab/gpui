defmodule GPUI.Remote.SessionRegistry do
  @moduledoc false

  alias GPUI.Remote.SessionGC
  alias GPUI.Remote.SessionSupervisor

  @event_request_limit 1_024

  @spec new() :: %{sessions: map(), monitors: map()}
  def new, do: %{sessions: %{}, monitors: %{}}

  @spec put(map(), term(), pid(), reference(), term()) :: map()
  def put(registry, session_id, session, monitor, mount_request) do
    entry = %{
      pid: session,
      monitor: monitor,
      last_seen: SessionGC.monotonic_ms(),
      mount_request: mount_request,
      event_requests: []
    }

    registry
    |> put_in([:sessions, session_id], entry)
    |> put_in([:monitors, monitor], session_id)
  end

  @spec fetch(map(), term()) :: {:ok, pid()} | {:error, :session_expired | :unknown_session}
  def fetch(registry, session_id) do
    case Map.fetch(registry.sessions, session_id) do
      {:ok, %{pid: session}} when is_pid(session) ->
        if Process.alive?(session), do: {:ok, session}, else: {:error, :session_expired}

      :error ->
        {:error, :unknown_session}
    end
  end

  @spec remove_down(map(), reference()) :: {:ok, term(), map()} | :error
  def remove_down(registry, monitor) do
    case Map.fetch(registry.monitors, monitor) do
      :error ->
        :error

      {:ok, session_id} ->
        registry = %{
          registry
          | sessions: Map.delete(registry.sessions, session_id),
            monitors: Map.delete(registry.monitors, monitor)
        }

        {:ok, session_id, registry}
    end
  end

  @spec drop(map(), term(), pid()) :: map()
  def drop(registry, session_id, supervisor) do
    case Map.pop(registry.sessions, session_id) do
      {nil, _sessions} ->
        registry

      {%{pid: session, monitor: monitor}, sessions} ->
        Process.demonitor(monitor, [:flush])
        SessionSupervisor.stop_session(supervisor, session)
        %{registry | sessions: sessions, monitors: Map.delete(registry.monitors, monitor)}
    end
  end

  @spec touch(map(), term()) :: map()
  def touch(registry, session_id) do
    update_in(registry.sessions, &SessionGC.touch_existing(&1, session_id))
  end

  @spec gc(map(), :infinity | non_neg_integer(), pid()) :: map()
  def gc(registry, ttl, supervisor) do
    {sessions, monitors} =
      Enum.reduce(registry.sessions, {%{}, registry.monitors}, fn {session_id, session},
                                                                  {sessions, monitors} ->
        if SessionGC.expired?(session, ttl) do
          Process.demonitor(session.monitor, [:flush])
          SessionSupervisor.stop_session(supervisor, session.pid)
          {sessions, Map.delete(monitors, session.monitor)}
        else
          {Map.put(sessions, session_id, session), monitors}
        end
      end)

    %{registry | sessions: sessions, monitors: monitors}
  end

  @spec repeated_mount?(map(), term(), term()) :: boolean()
  def repeated_mount?(_registry, _session_id, nil), do: false

  def repeated_mount?(registry, session_id, request_id) do
    match?(%{mount_request: ^request_id}, registry.sessions[session_id])
  end

  @spec repeated_event?(map(), term(), term()) :: boolean()
  def repeated_event?(_registry, _session_id, nil), do: false

  def repeated_event?(registry, session_id, request_id) do
    request_id in registry.sessions[session_id].event_requests
  end

  @spec remember_event(map(), term(), term()) :: map()
  def remember_event(registry, _session_id, nil), do: registry

  def remember_event(registry, session_id, request_id) do
    update_in(registry.sessions[session_id].event_requests, fn requests ->
      [request_id | requests] |> Enum.uniq() |> Enum.take(@event_request_limit)
    end)
  end

  @spec entry!(map(), term()) :: map()
  def entry!(registry, session_id), do: Map.fetch!(registry.sessions, session_id)
end
