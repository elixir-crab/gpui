defmodule GPUI.Remote.Session do
  @moduledoc false

  use GenServer

  alias GPUI.Remote.SessionTree
  alias GPUI.Remote.Supervision

  @event_request_limit 1_024

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def route(tree) do
    with {:ok, requests} <- Supervision.child(tree, :requests, :session_unavailable),
         {:ok, session} <- Supervision.child(tree, :coordinator, :session_unavailable) do
      {:ok, %{requests: requests, session: session, tree: tree}}
    end
  end

  def call(%{requests: requests, session: session}, request) do
    caller = self()
    reply_ref = make_ref()

    case Task.Supervisor.start_child(requests, fn ->
           send(caller, {reply_ref, safe_call(session, request)})
         end) do
      {:ok, task} -> await_request(task, reply_ref)
      {:error, :max_children} -> {:error, :overloaded}
      {:error, reason} -> {:error, {:session_unavailable, reason}}
    end
  catch
    :exit, reason -> {:error, {:session_unavailable, reason}}
  end

  @impl GenServer
  def init(opts) do
    state = %{
      app: Keyword.fetch!(opts, :app),
      args: Keyword.fetch!(opts, :args),
      session_id: Keyword.fetch!(opts, :session_id),
      session: nil,
      tree: Keyword.fetch!(opts, :tree),
      event_requests: [],
      ttl: Keyword.fetch!(opts, :ttl),
      expiry_timer: nil
    }

    {:ok, schedule_expiry(state)}
  end

  @impl GenServer
  def handle_call(:mount, _from, %{session: nil} = state) do
    case SessionTree.start_app_session(state.tree, app: state.app, args: state.args) do
      {:ok, session} ->
        snapshot = GPUI.Session.snapshot(session)
        state = state |> Map.put(:session, session) |> touch()
        {:reply, {:ok, %{session_id: state.session_id, snapshot: snapshot}}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, touch(state)}
    end
  end

  def handle_call(:mount, _from, state) do
    {:reply, mount_snapshot(state), touch(state)}
  end

  def handle_call(:resume, _from, %{session: nil} = state) do
    {:reply, {:error, :session_not_mounted}, touch(state)}
  end

  def handle_call(:resume, _from, state) do
    {:ok, snapshot} = session_snapshot(state)
    reply = {:ok, %{session_id: state.session_id, resumed: true, snapshot: snapshot}}
    {:reply, reply, touch(state)}
  end

  def handle_call(:snapshot, _from, state) do
    reply = with {:ok, snapshot} <- session_snapshot(state), do: {:ok, %{snapshot: snapshot}}
    {:reply, reply, touch(state)}
  end

  def handle_call({:event, event}, _from, state) do
    request_id = Map.get(event, :request_id)

    if repeated_event?(state, request_id) do
      reply = with {:ok, snapshot} <- session_snapshot(state), do: {:ok, %{snapshot: snapshot}}
      {:reply, reply, touch(state)}
    else
      apply_event(state, request_id, event)
    end
  end

  @impl GenServer
  def handle_info({:expire, token}, %{expiry_timer: {_timer, token}} = state),
    do: {:stop, :normal, state}

  def handle_info({:expire, _stale_token}, state), do: {:noreply, state}

  defp safe_call(session, request) do
    GenServer.call(session, request, :infinity)
  catch
    :exit, reason -> {:error, {:session_unavailable, reason}}
  end

  defp await_request(task, reply_ref) do
    monitor = Process.monitor(task)

    receive do
      {^reply_ref, reply} ->
        Process.demonitor(monitor, [:flush])
        reply

      {:DOWN, ^monitor, :process, ^task, reason} ->
        {:error, {:session_unavailable, reason}}
    end
  end

  defp apply_event(%{session: nil} = state, _request_id, _event) do
    {:reply, {:error, :session_not_mounted}, touch(state)}
  end

  defp apply_event(state, request_id, event) do
    event = Map.drop(event, [:session_id, :request_id])
    {_event, snapshot} = GPUI.Session.dispatch_event(state.session, event)
    state = state |> remember_event(request_id) |> touch()
    {:reply, {:ok, %{snapshot: snapshot}}, state}
  end

  defp mount_snapshot(state) do
    case session_snapshot(state) do
      {:ok, snapshot} -> {:ok, %{session_id: state.session_id, snapshot: snapshot}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp session_snapshot(%{session: nil}), do: {:error, :session_not_mounted}
  defp session_snapshot(state), do: {:ok, GPUI.Session.snapshot(state.session)}

  defp repeated_event?(_state, nil), do: false
  defp repeated_event?(state, request_id), do: request_id in state.event_requests

  defp remember_event(state, nil), do: state

  defp remember_event(state, request_id) do
    requests =
      [request_id | state.event_requests] |> Enum.uniq() |> Enum.take(@event_request_limit)

    %{state | event_requests: requests}
  end

  defp touch(state) do
    cancel_expiry(state.expiry_timer)
    state |> Map.put(:expiry_timer, nil) |> schedule_expiry()
  end

  defp schedule_expiry(%{ttl: :infinity} = state), do: state

  defp schedule_expiry(%{ttl: ttl, expiry_timer: nil} = state)
       when is_integer(ttl) and ttl >= 0 do
    token = make_ref()
    timer = Process.send_after(self(), {:expire, token}, ttl)
    %{state | expiry_timer: {timer, token}}
  end

  defp schedule_expiry(state), do: state

  defp cancel_expiry(nil), do: :ok
  defp cancel_expiry({timer, _token}), do: Process.cancel_timer(timer)
end
