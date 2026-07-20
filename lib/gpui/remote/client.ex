defmodule GPUI.Remote.Client do
  @moduledoc """
  Display-side client for a remote GPUI application session.

  The client owns a local display, synchronizes remote snapshots into it, and
  forwards local display events to `GPUI.Remote.Server`.

  ## Options

    * `:host` and `:port` - required remote endpoint;
    * `:ssl` - `false` or SafeRPC TLS options;
    * `:display` - local display module, defaulting to `GPUI.Display.Native`;
    * `:display_opts` - options passed to the display;
    * `:session_id` - stable session identity, generated when omitted;
    * `:poll_interval` - positive milliseconds or `nil` to disable display
      polling, defaulting to `16`;
    * `:name` - optional client process name.
  """

  use GenServer
  use GPUI.Display.FrameAPI

  alias GPUI.Remote.Protocol
  alias GPUI.Remote.Reconnect
  alias GPUI.Remote.Transport.TCP

  @reconnect_errors [:closed, :timeout, :econnrefused, :enetunreach, :nxdomain]
  @pending_event_limit 1_024

  @doc false
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts), do: GPUI.Remote.child_spec(__MODULE__, opts)

  @doc "Starts a remote display client linked to the caller."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    with {:ok, _poll_interval} <- GPUI.Polling.interval(opts) do
      GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
    end
  end

  @doc "Mounts or remounts the configured application session and synchronizes its snapshot."
  @spec mount(GenServer.server(), map() | keyword()) ::
          {:ok, GPUI.Snapshot.t()} | {:error, term()}
  def mount(client, args \\ %{}), do: GenServer.call(client, {:mount, args})

  @doc "Dispatches one normalized event remotely and synchronizes its snapshot."
  @spec event(GenServer.server(), map()) :: {:ok, GPUI.Snapshot.t()} | {:error, term()}
  def event(client, event), do: GenServer.call(client, {:event, event})

  @doc "Fetches and synchronizes the current remote session snapshot."
  @spec snapshot(GenServer.server()) :: {:ok, GPUI.Snapshot.t()} | {:error, term()}
  def snapshot(client), do: GenServer.call(client, :snapshot)

  @doc "Subscribes the calling process to synchronized remote display updates."
  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(client), do: GenServer.call(client, :subscribe)

  @doc "Unsubscribes the calling process from remote display updates."
  @spec unsubscribe(GenServer.server()) :: :ok
  def unsubscribe(client), do: GenServer.call(client, :unsubscribe)

  @impl GenServer
  def init(opts) do
    display_module = Keyword.get(opts, :display, GPUI.Display.Native)
    display_opts = Keyword.get(opts, :display_opts, [])

    case GPUI.Polling.interval(opts) do
      {:ok, poll_interval} ->
        case start_rpc_client(opts) do
          {:ok, rpc} -> start_display(rpc, display_module, display_opts, poll_interval, opts)
          {:error, reason} -> {:stop, {:rpc_start_failed, reason}}
        end

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp start_display(rpc, display_module, display_opts, poll_interval, opts) do
    case GPUI.Display.start(display_module, display_opts) do
      {:ok, display} ->
        state = %{
          opts: opts,
          rpc: rpc,
          display: display,
          display_module: display_module,
          mounted_args: nil,
          session_id: Keyword.get_lazy(opts, :session_id, &new_session_id/0),
          poll_interval: poll_interval,
          poll_timer: nil,
          pending_events: [],
          revision: 0,
          subscribers: %{}
        }

        {:ok, schedule_poll(state)}

      {:error, reason} ->
        Reconnect.stop_client(rpc)
        {:stop, {:display_start_failed, reason}}
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
    payload = %{args: args, session_id: state.session_id, request_id: new_request_id()}

    case call_with_reconnect(state, :mount, payload) do
      {:ok, %{snapshot: snapshot}, state} ->
        state = %{state | mounted_args: args}

        case synchronize_snapshot(state, snapshot, []) do
          {:ok, state} -> {:reply, {:ok, snapshot}, state}
          {:error, reason, state} -> {:reply, {:error, reason}, state}
        end

      {:ok, reply, state} ->
        {:reply, {:error, {:invalid_reply, :mount, reply}}, state}

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
    payload =
      event
      |> Map.put(:session_id, state.session_id)
      |> Map.put(:request_id, new_request_id())

    remote_snapshot_call(state, :event, payload)
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

  def handle_call({:frame_token, window_id}, from, state) do
    :ok =
      GPUI.Display.reply_from_display(
        state.display_module,
        state.display,
        :frame_token,
        [window_id],
        from
      )

    {:noreply, state}
  end

  def handle_call({:await_frame_after, window_id, generation, timeout}, from, state) do
    :ok =
      GPUI.Display.reply_from_display(
        state.display_module,
        state.display,
        :await_frame_after,
        [window_id, generation, timeout],
        from
      )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, monitor, :process, pid, _reason}, state) do
    subscribers = GPUI.UpdateSubscribers.remove_down(state.subscribers, pid, monitor)
    {:noreply, %{state | subscribers: subscribers}}
  end

  def handle_info({:poll_display, token}, %{poll_timer: token} = state) do
    state = state |> Map.put(:poll_timer, nil) |> forward_display_events() |> schedule_poll()
    {:noreply, state}
  end

  def handle_info({:poll_display, _stale_token}, state), do: {:noreply, state}

  def handle_info(:poll_display, state) do
    {:noreply, forward_display_events(state)}
  end

  defp remote_snapshot_call(state, op, payload) do
    case call_with_reconnect(state, op, payload) do
      {:ok, %{snapshot: snapshot}, state} ->
        events =
          if op == :event,
            do: [Map.drop(payload, [:session_id, :request_id])],
            else: nil

        case synchronize_snapshot(state, snapshot, events) do
          {:ok, state} -> {:reply, {:ok, snapshot}, state}
          {:error, reason, state} -> {:reply, {:error, reason}, state}
        end

      {:ok, reply, state} ->
        {:reply, {:error, {:invalid_reply, op, reply}}, state}

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
        synchronize_snapshot(state, snapshot, [])

      {:ok, reply} ->
        {:error, {:invalid_reply, :resume_session, reply}, state}

      {:error, reason} when reason in [:unknown_session, :session_expired] ->
        remount(state)

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp remount(state) do
    payload = %{
      args: state.mounted_args,
      session_id: state.session_id,
      request_id: new_request_id()
    }

    case safe_call(state.rpc, :mount, payload) do
      {:ok, %{snapshot: snapshot}} ->
        synchronize_snapshot(state, snapshot, [])

      {:ok, reply} ->
        {:error, {:invalid_reply, :mount, reply}, state}

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
    state =
      case safe_display_drain(state) do
        {:ok, events} -> enqueue_display_events(state, events)
        {:error, _reason} -> state
      end

    flush_pending_events(state)
  end

  defp safe_display_drain(state) do
    GPUI.Display.drain(state.display_module, state.display)
  end

  defp enqueue_display_events(state, events) do
    new_events =
      Enum.flat_map(events, fn event ->
        case display_event_payload(event, state.session_id) do
          nil -> []
          payload -> [payload]
        end
      end)

    pending = Enum.take(state.pending_events ++ new_events, -@pending_event_limit)
    %{state | pending_events: pending}
  end

  defp display_event_payload(%{type: type} = event, session_id)
       when type in [
              :click,
              :change,
              :select,
              :release,
              :search,
              :range,
              :keydown,
              :keyup,
              :window_closed
            ] do
    event
    |> GPUI.Event.normalize()
    |> Map.put(:session_id, session_id)
    |> Map.put(:request_id, new_request_id())
  end

  defp display_event_payload(_event, _session_id), do: nil

  defp flush_pending_events(%{pending_events: []} = state), do: state

  defp flush_pending_events(%{pending_events: [payload | rest]} = state) do
    case call_with_reconnect(state, :event, payload) do
      {:ok, %{snapshot: snapshot}, state} ->
        events = [Map.drop(payload, [:session_id, :request_id])]

        case synchronize_snapshot(%{state | pending_events: rest}, snapshot, events) do
          {:ok, state} -> flush_pending_events(state)
          {:error, _reason, state} -> %{state | pending_events: [payload | rest]}
        end

      {:ok, _reply, state} ->
        %{state | pending_events: [payload | rest]}

      {:error, _reason, state} ->
        %{state | pending_events: [payload | rest]}
    end
  end

  defp schedule_poll(%{poll_interval: nil} = state), do: state

  defp schedule_poll(%{poll_interval: interval, poll_timer: nil} = state) do
    token = make_ref()
    Process.send_after(self(), {:poll_display, token}, interval)
    %{state | poll_timer: token}
  end

  defp schedule_poll(state), do: state

  defp synchronize_snapshot(state, snapshot, events) do
    case safe_display_sync(state, snapshot) do
      :ok ->
        state =
          if is_list(events) do
            GPUI.UpdateSubscribers.publish_update(state, self(), events, snapshot)
          else
            state
          end

        {:ok, state}

      {:error, reason} ->
        {:error, {:display_sync_failed, reason}, state}
    end
  end

  defp safe_display_sync(state, snapshot) do
    GPUI.Display.sync_snapshot(state.display_module, state.display, snapshot)
  end

  defp new_session_id, do: unique_id()
  defp new_request_id, do: unique_id()

  defp unique_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp start_rpc_client(opts) do
    opts =
      opts
      |> Keyword.put(:transport, TCP)
      |> Keyword.put_new(:cap, Protocol.capability())

    case SafeRPC.Client.start_link(opts) do
      {:ok, client} -> negotiate_client(client)
      {:error, reason} -> {:error, reason}
    end
  end

  defp negotiate_client(client) do
    %{op: op, payload: payload} = Protocol.hello()

    case safe_call(client, op, payload) do
      {:ok, _hello} ->
        {:ok, client}

      {:error, reason} ->
        Reconnect.stop_client(client)
        {:error, reason}
    end
  end
end
