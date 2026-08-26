defmodule GPUI.Remote.Reconnect do
  @moduledoc "Bounded reconnect orchestration shared by the remote display client."

  @spec call_with_reconnect(term(), atom(), map(), function(), function(), [term()]) ::
          {:ok, term(), term()} | {:error, term(), term()}
  def call_with_reconnect(state, op, payload, safe_call, reconnect, reconnect_errors) do
    case safe_call.(state, op, payload) do
      {:ok, reply} ->
        {:ok, reply, state}

      {:error, reason} ->
        maybe_reconnect(reason, state, op, payload, safe_call, reconnect, reconnect_errors)
    end
  end

  defp maybe_reconnect(reason, state, op, payload, safe_call, reconnect, reconnect_errors) do
    if reconnectable?(reason, reconnect_errors) do
      reconnect_and_retry(state, op, payload, safe_call, reconnect)
    else
      {:error, reason, state}
    end
  end

  defp reconnect_and_retry(state, op, payload, safe_call, reconnect) do
    case reconnect.(state) do
      {:ok, state} -> retry_after_reconnect(state, op, payload, safe_call)
      {:error, reconnect_reason, state} -> {:error, reconnect_reason, state}
    end
  end

  defp retry_after_reconnect(state, op, payload, safe_call) do
    case safe_call.(state, op, payload) do
      {:ok, reply} -> {:ok, reply, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  @spec reconnectable?(term(), [term()]) :: boolean()
  def reconnectable?({:exit, _reason}, _reconnect_errors), do: true
  def reconnectable?(reason, reconnect_errors), do: reason in reconnect_errors

  @spec stop_client(pid() | nil) :: :ok
  def stop_client(nil), do: :ok

  def stop_client(client) when is_pid(client) do
    if Process.alive?(client), do: GenServer.stop(client)
    :ok
  catch
    :exit, _reason -> :ok
  end
end
