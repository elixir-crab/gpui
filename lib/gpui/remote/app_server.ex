defmodule GPUI.Remote.AppServer do
  @moduledoc """
  Remote OTP application endpoint for the inverted GPUI remote model.

  A local display client connects here, mounts a remote `GPUI.Application`, sends
  UI events, and receives rendered window snapshots back. SafeRPC handles the RPC
  mechanics; GPUI owns only app lifecycle operations.
  """

  use GenServer

  alias GPUI.Remote.AppProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP
  alias GPUI.Remote.Transport.TCP
  alias SafeRPC.Server.Connection

  @app_capability AppProtocol.capability()

  def child_spec(opts) do
    %{id: Keyword.get(opts, :name, __MODULE__), start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  def port(server), do: GenServer.call(server, :port)

  @impl GenServer
  def init(opts) do
    app = Keyword.fetch!(opts, :app)
    listen_opts = [port: Keyword.get(opts, :port, 0), ssl: Keyword.get(opts, :ssl, false)]

    with {:ok, listener} <- SafeRPCTCP.listen(listen_opts),
         {:ok, connection_supervisor} <- DynamicSupervisor.start_link(strategy: :one_for_one) do
      state = %{
        app: app,
        app_args: Keyword.get(opts, :args, []),
        runtime: nil,
        listener: listener,
        connection_supervisor: connection_supervisor,
        connections: %{}
      }

      start_acceptor(listener)
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_call(:port, _from, state), do: {:reply, TCP.port(state.listener), state}

  def handle_call({:dispatch, request}, _from, state) do
    {reply, state} = dispatch(request, state)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info({:gpui_remote_accepted, socket}, state) do
    start_acceptor(state.listener)

    child_spec = %{
      id: {Connection, System.unique_integer([:positive])},
      start:
        {Connection, :start_link,
         [[owner: self(), transport: SafeRPCTCP, socket: socket, recv_timeout: 5_000]]},
      restart: :temporary
    }

    {:ok, pid} = DynamicSupervisor.start_child(state.connection_supervisor, child_spec)
    Process.monitor(pid)
    {:noreply, put_in(state.connections[pid], socket)}
  end

  def handle_info({:gpui_remote_accept_error, reason}, state),
    do: {:stop, {:accept_failed, reason}, state}

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state),
    do: {:noreply, update_in(state.connections, &Map.delete(&1, pid))}

  @impl GenServer
  def terminate(_reason, state) do
    SafeRPCTCP.close(state.listener)
    Supervisor.stop(state.connection_supervisor)
  end

  defp dispatch(%{cap: cap}, state) when cap not in [nil, @app_capability],
    do: {{:error, :unauthorized}, state}

  defp dispatch(%{kind: :call, op: op, payload: payload}, state) do
    if AppProtocol.known_op?(op) do
      dispatch_call(op, payload, state)
    else
      {{:error, {:unsupported_op, op}}, state}
    end
  end

  defp dispatch(_request, state), do: {{:error, :unsupported_request}, state}

  defp dispatch_call(:hello, _payload, state) do
    {{:ok, %{version: 1, capabilities: [:app_server, :safe_rpc, :snapshot_v1]}}, state}
  end

  defp dispatch_call(:mount, payload, state) do
    args = Map.get(payload, :args, state.app_args)

    case ensure_runtime(%{state | app_args: args}) do
      {:ok, state} -> {{:ok, %{windows: snapshot(state)}}, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:snapshot, _payload, state) do
    case ensure_runtime(state) do
      {:ok, state} -> {{:ok, %{windows: snapshot(state)}}, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp dispatch_call(:event, event, state) do
    case ensure_runtime(state) do
      {:ok, %{runtime: runtime} = state} ->
        {_event, windows} = GPUI.Runtime.dispatch_event(runtime, event)
        {{:ok, %{windows: windows}}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp ensure_runtime(%{runtime: runtime} = state) when is_pid(runtime) do
    if Process.alive?(runtime), do: {:ok, state}, else: start_runtime(%{state | runtime: nil})
  end

  defp ensure_runtime(state), do: start_runtime(state)

  defp start_runtime(state) do
    case GPUI.Runtime.start_link(app: state.app, args: state.app_args, backend: :data) do
      {:ok, runtime} -> {:ok, %{state | runtime: runtime}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp snapshot(%{runtime: runtime}) do
    runtime
    |> GPUI.Runtime.windows()
    |> Enum.map(&GPUI.Runtime.window_payload/1)
  end

  defp start_acceptor(listener) do
    owner = self()

    Task.start(fn ->
      case SafeRPCTCP.accept(listener, :infinity) do
        {:ok, socket} ->
          :ok = TCP.controlling_process(socket, owner)
          send(owner, {:gpui_remote_accepted, socket})

        {:error, reason} ->
          send(owner, {:gpui_remote_accept_error, reason})
      end
    end)
  end
end
