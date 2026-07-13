defmodule GPUI.Remote.SessionSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name))
  end

  def start_session(supervisor, opts) do
    child_spec = %{
      id: {GPUI.Session, System.unique_integer([:positive])},
      start: {GPUI.Session, :start_link, [opts]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(supervisor, child_spec)
  end

  def stop_session(_supervisor, nil), do: :ok

  def stop_session(supervisor, session) when is_pid(session) do
    DynamicSupervisor.terminate_child(supervisor, session)
  end

  @impl DynamicSupervisor
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)
end
