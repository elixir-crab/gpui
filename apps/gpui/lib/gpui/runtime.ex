defmodule GPUI.Runtime do
  @moduledoc """
  Primary application-facing process API for one GPUI application and display.

  A runtime starts the renderer-independent `GPUI.Session`, owns the configured
  `GPUI.Display`, synchronizes authoritative snapshots, drains strict typed
  display events, and publishes completed updates to subscribers. Applications
  normally supervise their `GPUI.Application`, whose child specification starts
  this process; direct `GPUI.Session` use is reserved for remote hosting and
  custom display infrastructure.

  Use this module for application operations such as snapshots, resources,
  dynamic windows, view messages, subscriptions, and frame barriers.

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
  @sync_retry_interval 50

  @type display_error ::
          {:display_start_failed, term()}
          | {:display_sync_failed, term()}
          | {:display_drain_failed, term()}
          | {:display_inject_failed, term()}

  @type error :: GPUI.Session.operation_error() | GPUI.Session.topology_error() | display_error()

  @type state :: %{
          application: module(),
          identity: GPUI.Application.Identity.t() | nil,
          session: pid(),
          display: pid(),
          display_module: module(),
          events: [map()],
          poll_interval: pos_integer() | nil,
          revision: non_neg_integer(),
          subscribers: %{pid() => reference()},
          unsynchronized?: boolean()
        }

  @doc "Starts a runtime linked to the caller."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    with {:ok, _poll_interval} <- GPUI.Polling.interval(opts) do
      GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
    end
  end

  @doc "Returns stable runtime topology and synchronization information."
  @spec info(GenServer.server()) :: map()
  def info(runtime), do: GenServer.call(runtime, :info, @call_timeout)

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
  @spec drain_events(GenServer.server()) :: {:ok, [map()]} | {:error, error()}
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
  @spec put_resource(GenServer.server(), String.Chars.t(), map()) :: :ok | {:error, error()}
  def put_resource(runtime, id, resource),
    do: GenServer.call(runtime, {:put_resource, id, resource}, @call_timeout)

  @doc "Drops a session resource and synchronizes the resulting snapshot."
  @spec drop_resource(GenServer.server(), String.Chars.t()) :: :ok | {:error, error()}
  def drop_resource(runtime, id),
    do: GenServer.call(runtime, {:drop_resource, id}, @call_timeout)

  @doc "Validates and dispatches one explicit typed event and synchronizes the resulting snapshot."
  @spec dispatch_event(GenServer.server(), map()) ::
          {:ok, map(), GPUI.Snapshot.t()} | {:error, error()}
  def dispatch_event(runtime, event),
    do: GenServer.call(runtime, {:dispatch_event, event}, @call_timeout)

  @doc "Delivers an OTP message to a window's root view and synchronizes the display."
  @spec send_view(GenServer.server(), pos_integer(), term()) ::
          {:ok, GPUI.Snapshot.t()} | {:error, error()}
  def send_view(runtime, window_id, message),
    do: GenServer.call(runtime, {:send_view, window_id, message}, @call_timeout)

  @doc "Rerenders every window from its current module and assigns, then synchronizes the display."
  @spec refresh(GenServer.server()) :: {:ok, GPUI.Snapshot.t()} | {:error, error()}
  def refresh(runtime), do: GenServer.call(runtime, :refresh, @call_timeout)

  @doc "Injects an event into the active display queue without dispatching it immediately."
  @spec inject_event(GenServer.server(), map()) :: {:ok, term()} | {:error, error()}
  def inject_event(runtime, event),
    do: GenServer.call(runtime, {:inject_event, event}, @call_timeout)

  @doc "Requests a display frame for the current snapshot without changing application state."
  @spec request_frame(GenServer.server()) :: :ok | {:error, error()}
  def request_frame(runtime), do: GenServer.call(runtime, :request_frame, @call_timeout)

  @doc "Subscribes the calling process to synchronized runtime updates."
  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(runtime), do: GenServer.call(runtime, :subscribe, @call_timeout)

  @doc "Unsubscribes the calling process from runtime updates."
  @spec unsubscribe(GenServer.server()) :: :ok
  def unsubscribe(runtime), do: GenServer.call(runtime, :unsubscribe, @call_timeout)

  @impl GenServer
  def init(opts) do
    app = Keyword.fetch!(opts, :app)
    identity = GPUI.Application.identity(app)
    display_module = Keyword.get(opts, :display, GPUI.Display.Native)
    display_opts = Keyword.get(opts, :display_opts, [])

    display_opts =
      if identity,
        do: Keyword.put_new(display_opts, :application_identity, identity),
        else: display_opts

    with {:ok, poll_interval} <- GPUI.Polling.interval(opts),
         {:ok, session} <-
           GPUI.Session.start_link(
             app: app,
             args: Keyword.get(opts, :args, [])
           ),
         {:ok, display} <- start_display(display_module, display_opts),
         :ok <- sync_initial_snapshot(display_module, display, session) do
      state = %{
        application: app,
        identity: identity,
        session: session,
        display: display,
        display_module: display_module,
        events: [],
        poll_interval: poll_interval,
        revision: 0,
        subscribers: %{},
        unsynchronized?: false
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
  def handle_call(:info, _from, state) do
    windows = GPUI.Session.windows(state.session)

    {:reply,
     %{
       application: state.application,
       identity: state.identity,
       session: state.session,
       display: state.display_module,
       windows: length(windows),
       revision: state.revision,
       synchronized?: not state.unsynchronized?
     }, state}
  end

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
            state =
              state
              |> GPUI.UpdateSubscribers.publish_update(self(), [], snapshot)
              |> mark_synchronized(snapshot)

            {:reply, {:ok, id, snapshot}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, mark_unsynchronized(state)}
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
    case GPUI.Session.dispatch_event(state.session, event) do
      {:ok, handled, snapshot} ->
        case sync_display(state, snapshot) do
          :ok ->
            state =
              state
              |> GPUI.UpdateSubscribers.publish_update(self(), [handled], snapshot)
              |> record_events([handled])
              |> mark_synchronized(snapshot)

            {:reply, {:ok, handled, snapshot}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, mark_unsynchronized(state)}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
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
      {:ok, handled, state} -> {:reply, {:ok, handled}, state}
      {:error, reason, state} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:inject_event, event}, _from, state) do
    reply =
      case GPUI.Display.Support.inject(state.display_module, state.display, event) do
        {:ok, _value} = success -> success
        {:error, reason} -> {:error, {:display_inject_failed, reason}}
      end

    {:reply, reply, state}
  end

  def handle_call(:request_frame, _from, state) do
    case GPUI.Session.snapshot(state.session) do
      %GPUI.Snapshot{} = snapshot -> {:reply, sync_display(state, snapshot), state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:await_frame, window_id, timeout}, from, state) do
    :ok =
      GPUI.Display.Support.reply_after_frame(
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
      GPUI.Display.Support.reply_from_display(
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
      GPUI.Display.Support.reply_from_display(
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

  def handle_info(:retry_display_sync, state) do
    state = retry_unsynchronized(state)
    if state.unsynchronized?, do: schedule_sync_retry()
    {:noreply, state}
  end

  def handle_info(:poll_display, state) do
    state = retry_unsynchronized(state)

    state =
      case drain_display_events(state) do
        {:ok, _handled, state} -> state
        {:error, _reason, state} -> state
      end

    schedule_poll(state)
    {:noreply, state}
  end

  defp start_display(display_module, display_opts) do
    case GPUI.Display.Support.start(display_module, display_opts) do
      {:ok, display} -> {:ok, display}
      {:error, reason} -> {:error, {:display_start_failed, reason}}
    end
  end

  defp sync_initial_snapshot(display_module, display, session) do
    case GPUI.Display.Support.sync_snapshot(
           display_module,
           display,
           GPUI.Session.snapshot(session)
         ) do
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
        state =
          state
          |> GPUI.UpdateSubscribers.publish_update(self(), [], snapshot)
          |> mark_synchronized(snapshot)

        {:reply, {:ok, snapshot}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, mark_unsynchronized(state)}
    end
  end

  defp synchronized_snapshot_reply({:error, _reason} = error, state),
    do: {:reply, error, state}

  defp drain_display_events(state) do
    case GPUI.Display.Support.drain(state.display_module, state.display) do
      {:ok, events} -> apply_display_events(state, events)
      {:error, reason} -> {:error, {:display_drain_failed, reason}, state}
    end
  end

  defp apply_display_events(state, events) do
    case GPUI.Session.dispatch_events(state.session, events) do
      {:ok, handled, snapshot} -> synchronize_display_events(state, events, handled, snapshot)
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp synchronize_display_events(state, [], handled, _snapshot),
    do: {:ok, handled, record_events(state, handled)}

  defp synchronize_display_events(state, _events, handled, snapshot) do
    state = record_events(state, handled)

    case sync_display(state, snapshot) do
      :ok ->
        state =
          state
          |> GPUI.UpdateSubscribers.publish_update(self(), handled, snapshot)
          |> mark_synchronized(snapshot)

        {:ok, handled, state}

      {:error, reason} ->
        {:error, reason, mark_unsynchronized(state)}
    end
  end

  defp record_events(state, []), do: state

  defp record_events(state, handled) do
    events = handled |> Enum.reverse(state.events) |> Enum.take(@event_history_limit)
    %{state | events: events}
  end

  defp sync_and_publish(state) do
    case GPUI.Session.snapshot(state.session) do
      %GPUI.Snapshot{} = snapshot ->
        case sync_display(state, snapshot) do
          :ok ->
            state =
              state
              |> GPUI.UpdateSubscribers.publish_update(self(), [], snapshot)
              |> mark_synchronized(snapshot)

            {:ok, state}

          {:error, _reason} = error ->
            {error, mark_unsynchronized(state)}
        end

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp retry_unsynchronized(%{unsynchronized?: false} = state), do: state

  defp retry_unsynchronized(state) do
    case GPUI.Session.snapshot(state.session) do
      %GPUI.Snapshot{} = snapshot ->
        case sync_display(state, snapshot) do
          :ok ->
            state
            |> GPUI.UpdateSubscribers.publish_update(self(), [], snapshot)
            |> mark_synchronized(snapshot)

          {:error, _reason} ->
            state
        end

      {:error, _reason} ->
        state
    end
  end

  defp mark_unsynchronized(state) do
    schedule_sync_retry()
    %{state | unsynchronized?: true}
  end

  defp mark_synchronized(state, _snapshot), do: %{state | unsynchronized?: false}

  defp schedule_sync_retry do
    Process.send_after(self(), :retry_display_sync, @sync_retry_interval)
    :ok
  end

  defp sync_display(state, snapshot) do
    case GPUI.Display.Support.sync_snapshot(state.display_module, state.display, snapshot) do
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
