defmodule GPUI.Remote.SessionTree do
  @moduledoc "Supervisor tree that owns one remote GPUI session and request route."

  use Supervisor

  alias GPUI.Remote.Session

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  def start_app_session(tree, opts) do
    child_spec = %{
      id: :app_session,
      start: {GPUI.Session, :start_link_deferred, [opts]},
      restart: :temporary,
      significant: true
    }

    Supervisor.start_child(tree, child_spec)
  catch
    :exit, reason -> {:error, {:session_unavailable, reason}}
  end

  @impl Supervisor
  def init(opts) do
    tree = self()

    children = [
      %{
        id: :requests,
        start:
          {Task.Supervisor, :start_link, [[max_children: Keyword.fetch!(opts, :request_limit)]]},
        restart: :temporary,
        significant: true,
        type: :supervisor
      },
      %{
        id: :coordinator,
        start: {Session, :start_link, [Keyword.put(opts, :tree, tree)]},
        restart: :temporary,
        significant: true
      }
    ]

    Supervisor.init(children,
      strategy: :one_for_one,
      auto_shutdown: :any_significant
    )
  end
end
