defmodule GPUI.Remote.SessionGC do
  @moduledoc false

  @spec schedule(:infinity | pos_integer(), term()) :: :ok
  def schedule(:infinity, _message), do: :ok

  def schedule(interval, message) when is_integer(interval) and interval > 0 do
    Process.send_after(self(), message, interval)
    :ok
  end

  @spec reject_expired(map(), :infinity | non_neg_integer(), (term(), map() -> term())) :: map()
  def reject_expired(sessions, :infinity, _on_expired), do: sessions

  def reject_expired(sessions, ttl, on_expired) when is_integer(ttl) and ttl >= 0 do
    now = System.monotonic_time(:millisecond)

    sessions
    |> Enum.reject(fn {session_id, session} ->
      expired? = now - Map.get(session, :last_seen, now) > ttl
      if expired?, do: on_expired.(session_id, session)
      expired?
    end)
    |> Map.new()
  end

  @spec touch_existing(map(), term()) :: map()
  def touch_existing(sessions, session_id) do
    if Map.has_key?(sessions, session_id) do
      update_in(sessions, [session_id], &Map.put(&1, :last_seen, monotonic_ms()))
    else
      sessions
    end
  end

  @spec monotonic_ms() :: integer()
  def monotonic_ms, do: System.monotonic_time(:millisecond)
end
