defmodule GPUI.Remote.SessionRegistry do
  @moduledoc "Tracks remote session routes, monitors, request IDs, and expiry metadata."

  alias GPUI.Remote.SessionSupervisor

  @spec new() :: %{sessions: map(), monitors: map()}
  def new, do: %{sessions: %{}, monitors: %{}}

  @spec put(map(), term(), pid(), map(), reference(), term()) :: map()
  def put(registry, session_id, session, route, monitor, mount_request) do
    entry = %{pid: session, route: route, monitor: monitor, mount_request: mount_request}

    registry
    |> put_in([:sessions, session_id], entry)
    |> put_in([:monitors, monitor], session_id)
  end

  @spec fetch(map(), term()) :: {:ok, map()} | {:error, :session_expired | :unknown_session}
  def fetch(registry, session_id) do
    case Map.fetch(registry.sessions, session_id) do
      {:ok, %{pid: session, route: route}} when is_pid(session) ->
        if Process.alive?(session), do: {:ok, route}, else: {:error, :session_expired}

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

  @spec drop(map(), term()) :: map()
  def drop(registry, session_id) do
    case Map.pop(registry.sessions, session_id) do
      {nil, _sessions} ->
        registry

      {%{pid: session, monitor: monitor}, sessions} ->
        Process.demonitor(monitor, [:flush])
        SessionSupervisor.stop_session(session)
        %{registry | sessions: sessions, monitors: Map.delete(registry.monitors, monitor)}
    end
  end

  @spec repeated_mount?(map(), term(), term()) :: boolean()
  def repeated_mount?(_registry, _session_id, nil), do: false

  def repeated_mount?(registry, session_id, request_id) do
    match?(%{mount_request: ^request_id}, registry.sessions[session_id])
  end
end
