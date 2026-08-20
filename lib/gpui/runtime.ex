defmodule GPUI.Runtime do
  @moduledoc """
  Local composition of a renderer-independent `GPUI.Session` and a display.

  The runtime synchronizes session snapshots to the display and routes display
  events back into the session. Remote application servers use `GPUI.Session`
  directly and therefore never start a native display.

  ## Options

    * `:app` - required `GPUI.Application` module;
    * `:args` - application mount argument, defaulting to `[]`;
    * `:display` - display module, defaulting to `GPUI.Display.Native`;
    * `:display_opts` - options passed to the display;
    * `:poll_interval` - positive milliseconds or `nil` to disable polling,
      defaulting to `16`;
    * `:name` - optional runtime process name.
  """

  use GenServer
  use GPUI.Display.FrameAPI

  @call_timeout 5_000
  @event_history_limit 1_000

  @type state :: %{
          session: pid(),
          display: pid(),
          display_module: module(),
          events: [map()],
          poll_interval: pos_integer() | nil,
          revision: non_neg_integer(),
          subscribers: %{pid() => reference()}
        }

  @doc "Starts a runtime linked to the caller."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    with {:ok, _poll_interval} <- GPUI.Polling.interval(opts) do
      GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
    end
  end

  @doc "Returns the runtime session's declarative windows."
  @spec windows(GenServer.server()) :: [GPUI.WindowSpec.t()]
  def windows(runtime), do: GenServer.call(runtime, :windows, @call_timeout)

  @doc "Returns the current authoritative session snapshot."
  @spec snapshot(GenServer.server()) :: GPUI.Snapshot.t()
  def snapshot(runtime), do: GenServer.call(runtime, :snapshot, @call_timeout)

  @doc "Returns the bounded history of handled display events."
  @spec events(GenServer.server()) :: [map()]
  def events(runtime), do: GenServer.call(runtime, :events, @call_timeout)

  @doc "Drains display events, applies them to the session, and synchronizes the result."
  @spec drain_events(GenServer.server()) :: [map()] | {:error, term()}
  def drain_events(runtime), do: GenServer.call(runtime, :drain_events, @call_timeout)

  @doc "Adds a keyed declarative window and synchronizes it to the display."
  @spec open_window(GenServer.server(), GPUI.WindowSpec.t()) ::
          {:ok, pos_integer(), GPUI.Snapshot.t()} | {:error, GPUI.Session.topology_error()}
  def open_window(runtime, window),
    do: GenServer.call(runtime, {:open_window, window}, @call_timeout)

  @doc "Closes a declarative window by key or session ID and synchronizes the display."
  @spec close_window(GenServer.server(), GPUI.WindowSpec.key() | pos_integer()) ::
          {:ok, GPUI.Snapshot.t()} | {:error, GPUI.Session.topology_error()}
  def close_window(runtime, window),
    do: GenServer.call(runtime, {:close_window, window}, @call_timeout)

  @doc "Stores a session resource and synchronizes the resulting snapshot."
  @spec put_resource(GenServer.server(), String.Chars.t(), map()) :: :ok | {:error, term()}
  def put_resource(runtime, id, resource),
    do: GenServer.call(runtime, {:put_resource, id, resource}, @call_timeout)

  @doc "Drops a session resource and synchronizes the resulting snapshot."
  @spec drop_resource(GenServer.server(), String.Chars.t()) :: :ok | {:error, term()}
  def drop_resource(runtime, id),
    do: GenServer.call(runtime, {:drop_resource, id}, @call_timeout)

  @doc "Dispatches one normalized event and synchronizes the resulting snapshot."
  @spec dispatch_event(GenServer.server(), map()) ::
          {map(), GPUI.Snapshot.t()} | {:error, term()}
  def dispatch_event(runtime, event),
    do: GenServer.call(runtime, {:dispatch_event, event}, @call_timeout)

  @doc "Delivers an OTP message to a window's root view and synchronizes the display."
  @spec send_view(GenServer.server(), pos_integer(), term()) ::
          {:ok, GPUI.Snapshot.t()} | {:error, term()}
  def send_view(runtime, window_id, message),
    do: GenServer.call(runtime, {:send_view, window_id, message}, @call_timeout)

  @doc "Rerenders every window from its current module and assigns, then synchronizes the display."
  @spec refresh(GenServer.server()) :: {:ok, GPUI.Snapshot.t()} | {:error, term()}
  def refresh(runtime), do: GenServer.call(runtime, :refresh, @call_timeout)

  @doc "Injects an event into the active display queue without dispatching it immediately."
  @spec inject_event(GenServer.server(), map()) :: {:ok, term()} | {:error, term()}
  def inject_event(runtime, event),
    do: GenServer.call(runtime, {:inject_event, event}, @call_timeout)

  @doc "Requests a display frame for the current snapshot without changing application state."
  @spec request_frame(GenServer.server()) :: :ok | {:error, term()}
  def request_frame(runtime), do: GenServer.call(runtime, :request_frame, @call_timeout)

  @doc "Subscribes the calling process to synchronized runtime updates."
  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(runtime), do: GenServer.call(runtime, :subscribe, @call_timeout)

  @doc "Unsubscribes the calling process from runtime updates."
  @spec unsubscribe(GenServer.server()) :: :ok
  def unsubscribe(runtime), do: GenServer.call(runtime, :unsubscribe, @call_timeout)

  @impl GenServer
  def init(opts) do
    display_module = Keyword.get(opts, :display, GPUI.Display.Native)
    display_opts = Keyword.get(opts, :display_opts, [])

    with {:ok, poll_interval} <- GPUI.Polling.interval(opts),
         {:ok, session} <-
           GPUI.Session.start_link(
             app: Keyword.fetch!(opts, :app),
             args: Keyword.get(opts, :args, [])
           ),
         {:ok, display} <- start_display(display_module, display_opts),
         :ok <- sync_initial_snapshot(display_module, display, session) do
      state = %{
        session: session,
        display: display,
        display_module: display_module,
        events: [],
        poll_interval: poll_interval,
        revision: 0,
        subscribers: %{}
      }

      schedule_poll(state)
      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    stop_child(state.display)
    stop_child(state.session)
  end

  @impl GenServer
  def handle_call(:windows, _from, state),
    do: {:reply, GPUI.Session.windows(state.session), state}

  def handle_call(:snapshot, _from, state),
    do: {:reply, GPUI.Session.snapshot(state.session), state}

  def handle_call(:events, _from, state), do: {:reply, Enum.reverse(state.events), state}

  def handle_call(:subscribe, {pid, _tag}, state) do
    subscribers = GPUI.UpdateSubscribers.subscribe(state.subscribers, pid)
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_call(:unsubscribe, {pid, _tag}, state) do
    subscribers = GPUI.UpdateSubscribers.unsubscribe(state.subscribers, pid)
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_call({:open_window, window}, _from, state) do
    case GPUI.Session.open_window(state.session, window) do
      {:ok, id, snapshot} ->
        case sync_display(state, snapshot) do
          :ok ->
            state = GPUI.UpdateSubscribers.publish_update(state, self(), [], snapshot)
            {:reply, {:ok, id, snapshot}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:close_window, window}, _from, state) do
    state.session
    |> GPUI.Session.close_window(window)
    |> synchronized_snapshot_reply(state)
  end

  def handle_call({:put_resource, id, resource}, _from, state) do
    :ok = GPUI.Session.put_resource(state.session, id, resource)
    {reply, state} = sync_and_publish(state)
    {:reply, reply, state}
  end

  def handle_call({:drop_resource, id}, _from, state) do
    :ok = GPUI.Session.drop_resource(state.session, id)
    {reply, state} = sync_and_publish(state)
    {:reply, reply, state}
  end

  def handle_call({:dispatch_event, event}, _from, state) do
    {handled, snapshot} = GPUI.Session.dispatch_event(state.session, event)

    case sync_display(state, snapshot) do
      :ok ->
        state =
          state
          |> GPUI.UpdateSubscribers.publish_update(self(), [handled], snapshot)
          |> record_events([handled])

        {:reply, {handled, snapshot}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, record_events(state, [handled])}
    end
  end

  def handle_call({:send_view, window_id, message}, _from, state) do
    state.session
    |> GPUI.Session.send_view(window_id, message)
    |> synchronized_snapshot_reply(state)
  end

  def handle_call(:refresh, _from, state) do
    state.session
    |> GPUI.Session.refresh()
    |> synchronized_snapshot_reply(state)
  end

  def handle_call(:drain_events, _from, state) do
    case drain_display_events(state) do
      {:ok, handled, state} -> {:reply, handled, state}
      {:error, reason, state} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:inject_event, event}, _from, state) do
    reply =
      case GPUI.Display.inject(state.display_module, state.display, event) do
        {:ok, _value} = success -> success
        {:error, reason} -> {:error, {:display_inject_failed, reason}}
      end

    {:reply, reply, state}
  end

  def handle_call(:request_frame, _from, state) do
    snapshot = GPUI.Session.snapshot(state.session)
    {:reply, sync_display(state, snapshot), state}
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

  def handle_info(:poll_display, state) do
    state =
      case drain_display_events(state) do
        {:ok, _handled, state} -> state
        {:error, _reason, state} -> state
      end

    schedule_poll(state)
    {:noreply, state}
  end

  defp start_display(display_module, display_opts) do
    case GPUI.Display.start(display_module, display_opts) do
      {:ok, display} -> {:ok, display}
      {:error, reason} -> {:error, {:display_start_failed, reason}}
    end
  end

  defp sync_initial_snapshot(display_module, display, session) do
    case GPUI.Display.sync_snapshot(display_module, display, GPUI.Session.snapshot(session)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:display_sync_failed, reason}}
    end
  end

  defp stop_child(child) do
    if Process.alive?(child), do: GenServer.stop(child)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp synchronized_snapshot_reply({:ok, snapshot}, state) do
    case sync_display(state, snapshot) do
      :ok ->
        state = GPUI.UpdateSubscribers.publish_update(state, self(), [], snapshot)
        {:reply, {:ok, snapshot}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp synchronized_snapshot_reply({:error, _reason} = error, state),
    do: {:reply, error, state}

  defp drain_display_events(state) do
    case GPUI.Display.drain(state.display_module, state.display) do
      {:ok, events} -> apply_display_events(state, events)
      {:error, reason} -> {:error, {:display_drain_failed, reason}, state}
    end
  end

  defp apply_display_events(state, events) do
    {handled, snapshot} = GPUI.Session.dispatch_events(state.session, events)
    state = record_events(state, handled)

    if events == [] do
      {:ok, handled, state}
    else
      case sync_display(state, snapshot) do
        :ok ->
          state = GPUI.UpdateSubscribers.publish_update(state, self(), handled, snapshot)
          {:ok, handled, state}

        {:error, reason} ->
          {:error, reason, state}
      end
    end
  end

  defp record_events(state, []), do: state

  defp record_events(state, handled) do
    events = handled |> Enum.reverse(state.events) |> Enum.take(@event_history_limit)
    %{state | events: events}
  end

  defp sync_and_publish(state) do
    snapshot = GPUI.Session.snapshot(state.session)

    case sync_display(state, snapshot) do
      :ok -> {:ok, GPUI.UpdateSubscribers.publish_update(state, self(), [], snapshot)}
      {:error, _reason} = error -> {error, state}
    end
  end

  defp sync_display(state, snapshot) do
    case GPUI.Display.sync_snapshot(state.display_module, state.display, snapshot) do
      :ok -> :ok
      {:error, reason} -> {:error, {:display_sync_failed, reason}}
    end
  end

  defp schedule_poll(%{poll_interval: nil}), do: :ok

  defp schedule_poll(%{poll_interval: interval}) do
    Process.send_after(self(), :poll_display, interval)
    :ok
  end
end
