defmodule GPUI.Remote.Client do
  @moduledoc """
  Display-side client for a remote GPUI application session.

  The client owns a local display, synchronizes remote snapshots into it, and
  forwards local display events to `GPUI.Remote.Server`.
  """

  use GenServer

  alias GPUI.Remote.Protocol
  alias GPUI.Remote.Reconnect
  alias GPUI.Remote.Transport.TCP

  @reconnect_errors [:closed, :timeout, :econnrefused, :enetunreach, :nxdomain]

  def child_spec(opts), do: GPUI.Remote.child_spec(__MODULE__, opts)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  def mount(client, args \\ %{}), do: GenServer.call(client, {:mount, args})
  def event(client, event), do: GenServer.call(client, {:event, event})
  def snapshot(client), do: GenServer.call(client, :snapshot)

  @doc "Subscribes the calling process to synchronized remote display updates."
  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(client), do: GenServer.call(client, :subscribe)

  @doc "Unsubscribes the calling process from remote display updates."
  @spec unsubscribe(GenServer.server()) :: :ok
  def unsubscribe(client), do: GenServer.call(client, :unsubscribe)

  @doc "Waits for the current local display frame of a remote window."
  @spec await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
          :ok | {:error, term()}
  def await_frame(client, window_id, timeout \\ 5_000),
    do: GPUI.Display.call_await_frame(client, window_id, timeout)

  @impl GenServer
  def init(opts) do
    display_module = Keyword.get(opts, :display, GPUI.Display.Native)
    display_opts = Keyword.get(opts, :display_opts, [])

    with {:ok, rpc} <- start_rpc_client(opts),
         {:ok, display} <- display_module.start_link(display_opts) do
      state = %{
        opts: opts,
        rpc: rpc,
        display: display,
        display_module: display_module,
        mounted_args: nil,
        session_id: Keyword.get_lazy(opts, :session_id, &new_session_id/0),
        poll_interval: poll_interval(opts),
        revision: 0,
        subscribers: %{}
      }

      {:ok, schedule_poll(state)}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    Reconnect.stop_client(state.rpc)
    stop_display(state.display)
  end

  @impl GenServer
  def handle_call({:mount, args}, _from, state) do
    args = Map.new(args)
    payload = %{args: args, session_id: state.session_id}

    case call_with_reconnect(state, :mount, payload) do
      {:ok, %{snapshot: snapshot}, state} ->
        :ok = state.display_module.sync(state.display, snapshot)
        state = GPUI.UpdateSubscribers.publish_update(state, self(), [], snapshot)
        {:reply, {:ok, snapshot}, %{state | mounted_args: args}}

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:subscribe, {pid, _tag}, state) do
    subscribers = GPUI.UpdateSubscribers.subscribe(state.subscribers, pid)
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_call(:unsubscribe, {pid, _tag}, state) do
    subscribers = GPUI.UpdateSubscribers.unsubscribe(state.subscribers, pid)
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_call({:event, event}, _from, state) do
    remote_snapshot_call(state, :event, Map.put(event, :session_id, state.session_id))
  end

  def handle_call(:snapshot, _from, state) do
    remote_snapshot_call(state, :snapshot, %{session_id: state.session_id})
  end

  def handle_call({:await_frame, window_id, timeout}, from, state) do
    :ok =
      GPUI.Display.reply_after_frame(
        state.display_module,
        state.display,
        window_id,
        timeout,
        from
      )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, monitor, :process, pid, _reason}, state) do
    subscribers = GPUI.UpdateSubscribers.remove_down(state.subscribers, pid, monitor)
    {:noreply, %{state | subscribers: subscribers}}
  end

  def handle_info(:poll_display, state) do
    state = forward_display_events(state)
    schedule_poll(state)
    {:noreply, state}
  end

  defp remote_snapshot_call(state, op, payload) do
    case call_with_reconnect(state, op, payload) do
      {:ok, %{snapshot: snapshot}, state} ->
        :ok = state.display_module.sync(state.display, snapshot)

        state =
          if op == :event do
            GPUI.UpdateSubscribers.publish_update(
              state,
              self(),
              [Map.delete(payload, :session_id)],
              snapshot
            )
          else
            state
          end

        {:reply, {:ok, snapshot}, state}

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp call_with_reconnect(state, op, payload) do
    Reconnect.call_with_reconnect(
      state,
      op,
      payload,
      &safe_call_from_state/3,
      &reconnect/1,
      @reconnect_errors
    )
  end

  defp safe_call_from_state(state, op, payload), do: safe_call(state.rpc, op, payload)

  defp reconnect(state) do
    Reconnect.stop_client(state.rpc)

    case start_rpc_client(state.opts) do
      {:ok, rpc} -> resume_or_remount(%{state | rpc: rpc})
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp resume_or_remount(%{mounted_args: nil} = state), do: {:ok, state}

  defp resume_or_remount(state) do
    case safe_call(state.rpc, :resume_session, %{session_id: state.session_id}) do
      {:ok, %{snapshot: snapshot}} ->
        :ok = state.display_module.sync(state.display, snapshot)
        {:ok, GPUI.UpdateSubscribers.publish_update(state, self(), [], snapshot)}

      {:error, _reason} ->
        remount(state)
    end
  end

  defp remount(state) do
    payload = %{args: state.mounted_args, session_id: state.session_id}

    case safe_call(state.rpc, :mount, payload) do
      {:ok, %{snapshot: snapshot}} ->
        :ok = state.display_module.sync(state.display, snapshot)
        {:ok, GPUI.UpdateSubscribers.publish_update(state, self(), [], snapshot)}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp safe_call(client, op, payload) do
    SafeRPC.call(client, op, payload)
  catch
    :exit, {:noproc, _} -> {:error, :closed}
    :exit, {:normal, _} -> {:error, :closed}
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp stop_display(display) do
    if Process.alive?(display), do: GenServer.stop(display)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp forward_display_events(state) do
    case state.display_module.drain_events(state.display) do
      {:ok, events} -> Enum.reduce(events, state, &forward_display_event/2)
      {:error, _reason} -> state
    end
  end

  defp forward_display_event(%{type: type} = event, state)
       when type in [:click, :change, :keydown, :keyup, :window_closed] do
    payload = event |> GPUI.Event.normalize() |> Map.put(:session_id, state.session_id)

    case call_with_reconnect(state, :event, payload) do
      {:ok, %{snapshot: snapshot}, state} ->
        :ok = state.display_module.sync(state.display, snapshot)

        GPUI.UpdateSubscribers.publish_update(
          state,
          self(),
          [Map.delete(payload, :session_id)],
          snapshot
        )

      {:error, _reason, state} ->
        state
    end
  end

  defp forward_display_event(_event, state), do: state

  defp poll_interval(opts) do
    case Keyword.get(opts, :poll_interval, 16) do
      interval when is_integer(interval) and interval > 0 -> interval
      _other -> nil
    end
  end

  defp schedule_poll(%{poll_interval: nil} = state), do: state

  defp schedule_poll(%{poll_interval: interval} = state) do
    Process.send_after(self(), :poll_display, interval)
    state
  end

  defp new_session_id, do: System.unique_integer([:positive, :monotonic])

  defp start_rpc_client(opts) do
    opts =
      opts
      |> Keyword.put(:transport, TCP)
      |> Keyword.put_new(:cap, Protocol.capability())

    with {:ok, client} <- SafeRPC.Client.start_link(opts),
         %{op: op, payload: payload} = Protocol.hello(),
         {:ok, _hello} <- safe_call(client, op, payload) do
      {:ok, client}
    end
  end
end
