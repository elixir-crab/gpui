defmodule GPUI.Remote.SessionSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name))
  end

  def start_session(supervisor, opts) do
    child_spec = %{
      id: {GPUI.Remote.SessionTree, System.unique_integer([:positive])},
      start: {GPUI.Remote.SessionTree, :start_link, [opts]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(supervisor, child_spec)
  end

  def stop_session(session) when is_pid(session) do
    if Process.alive?(session), do: Supervisor.stop(session)
    :ok
  catch
    :exit, _reason -> :ok
  end

  @impl DynamicSupervisor
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)
end
