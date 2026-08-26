defmodule GPUI.Remote.Supervision do
  @moduledoc "Helpers for locating named children inside internal supervision trees."

  def child(supervisor, id, unavailable) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(fn
      {^id, pid, _type, _modules} when is_pid(pid) -> {:ok, pid}
      _child -> nil
    end)
    |> case do
      {:ok, pid} -> {:ok, pid}
      nil -> {:error, {unavailable, id}}
    end
  catch
    :exit, reason -> {:error, {unavailable, reason}}
  end
end
