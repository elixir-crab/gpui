defmodule GPUI.Remote.ServerSupervisor do
  @moduledoc false

  use Supervisor

  alias GPUI.Remote.Server
  alias GPUI.Remote.SessionSupervisor

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
        start: {SessionSupervisor, :start_link, [[]]},
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
