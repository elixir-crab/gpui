defmodule GPUI.Remote.Server.Supervisor do
  @moduledoc "Top-level supervisor for the remote server coordinator and dynamic children."

  use Supervisor

  alias GPUI.Remote.Server
  alias GPUI.Remote.SessionPool

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @impl Supervisor
  def init(opts) do
    tree = self()

    children = [
      %{
        id: :connections,
        start: {DynamicSupervisor, :start_link, [[strategy: :one_for_one]]},
        type: :supervisor
      },
      %{
        id: :sessions,
        start: {SessionPool, :start_link, [[]]},
        type: :supervisor
      },
      %{
        id: :coordinator,
        start: {Server, :start_coordinator, [Keyword.put(opts, :tree, tree)]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
