defmodule GPUI.Remote.ConnectionTree do
  @moduledoc false

  use Supervisor

  alias GPUI.Remote.Connection
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Server.Connection, as: RPCConnection

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  def start_rpc(tree, owner, socket) do
    child_spec = %{
      id: :rpc,
      start:
        {RPCConnection, :start_link,
         [[owner: owner, transport: TCP, socket: socket, recv_timeout: 5_000]]},
      restart: :temporary,
      significant: true
    }

    Supervisor.start_child(tree, child_spec)
  catch
    :exit, reason -> {:error, {:connection_unavailable, reason}}
  end

  @impl Supervisor
  def init(opts) do
    children = [
      %{
        id: :tasks,
        start: {Task.Supervisor, :start_link, [[]]},
        restart: :temporary,
        significant: true,
        type: :supervisor
      },
      %{
        id: :owner,
        start: {Connection, :start_link, [opts]},
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
