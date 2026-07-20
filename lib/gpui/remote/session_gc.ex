defmodule GPUI.Remote.SessionGC do
  @moduledoc false

  @spec schedule(:infinity | pos_integer(), term()) :: :ok
  def schedule(:infinity, _message), do: :ok

  def schedule(interval, message) when is_integer(interval) and interval > 0 do
    Process.send_after(self(), message, interval)
    :ok
  end

  @spec expired?(map(), :infinity | non_neg_integer()) :: boolean()
  def expired?(_session, :infinity), do: false

  def expired?(session, ttl) when is_integer(ttl) and ttl >= 0 do
    monotonic_ms() - Map.get(session, :last_seen, monotonic_ms()) > ttl
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
