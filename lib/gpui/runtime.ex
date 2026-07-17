defmodule GPUI.Runtime do
  @moduledoc """
  Local composition of a renderer-independent `GPUI.Session` and a display.

  The runtime synchronizes session snapshots to the display and routes display
  events back into the session. Remote application servers use `GPUI.Session`
  directly and therefore never start a native display.
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

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @spec windows(GenServer.server()) :: [GPUI.WindowSpec.t()]
  def windows(runtime), do: GenServer.call(runtime, :windows, @call_timeout)

  @spec snapshot(GenServer.server()) :: GPUI.Snapshot.t()
  def snapshot(runtime), do: GenServer.call(runtime, :snapshot, @call_timeout)

  @spec events(GenServer.server()) :: [map()]
  def events(runtime), do: GenServer.call(runtime, :events, @call_timeout)

  @spec drain_events(GenServer.server()) :: [map()]
  def drain_events(runtime), do: GenServer.call(runtime, :drain_events, @call_timeout)

  @spec put_resource(GenServer.server(), String.Chars.t(), map()) :: :ok | {:error, term()}
  def put_resource(runtime, id, resource),
    do: GenServer.call(runtime, {:put_resource, id, resource}, @call_timeout)

  @spec drop_resource(GenServer.server(), String.Chars.t()) :: :ok | {:error, term()}
  def drop_resource(runtime, id),
    do: GenServer.call(runtime, {:drop_resource, id}, @call_timeout)

  @spec dispatch_event(GenServer.server(), map()) :: {map(), GPUI.Snapshot.t()}
  def dispatch_event(runtime, event),
    do: GenServer.call(runtime, {:dispatch_event, event}, @call_timeout)

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

    with {:ok, session} <-
           GPUI.Session.start_link(
             app: Keyword.fetch!(opts, :app),
             args: Keyword.get(opts, :args, [])
           ),
         {:ok, display} <- display_module.start_link(display_opts),
         :ok <- display_module.sync(display, GPUI.Session.snapshot(session)) do
      state = %{
        session: session,
        display: display,
        display_module: display_module,
        events: [],
        poll_interval: poll_interval(opts),
        revision: 0,
        subscribers: %{}
      }

      schedule_poll(state)
      {:ok, state}
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
    :ok = state.display_module.sync(state.display, snapshot)
    state = GPUI.UpdateSubscribers.publish_update(state, self(), [handled], snapshot)
    {:reply, {handled, snapshot}, state}
  end

  def handle_call(:drain_events, _from, state) do
    {handled, state} = drain_display_events(state)
    {:reply, handled, state}
  end

  def handle_call({:inject_event, event}, _from, state) do
    {:reply, state.display_module.inject_event(state.display, event), state}
  end

  def handle_call(:request_frame, _from, state) do
    snapshot = GPUI.Session.snapshot(state.session)
    {:reply, state.display_module.sync(state.display, snapshot), state}
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
    {handled, state} = drain_display_events(state)
    events = handled |> Enum.reverse(state.events) |> Enum.take(@event_history_limit)
    state = %{state | events: events}
    schedule_poll(state)
    {:noreply, state}
  end

  defp stop_child(child) do
    if Process.alive?(child), do: GenServer.stop(child)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp drain_display_events(state) do
    {:ok, events} = state.display_module.drain_events(state.display)
    {handled, snapshot} = GPUI.Session.dispatch_events(state.session, events)

    state =
      if events == [] do
        state
      else
        :ok = state.display_module.sync(state.display, snapshot)
        GPUI.UpdateSubscribers.publish_update(state, self(), handled, snapshot)
      end

    {handled, state}
  end

  defp sync_and_publish(state) do
    snapshot = GPUI.Session.snapshot(state.session)

    case state.display_module.sync(state.display, snapshot) do
      :ok -> {:ok, GPUI.UpdateSubscribers.publish_update(state, self(), [], snapshot)}
      {:error, _reason} = error -> {error, state}
    end
  end

  defp poll_interval(opts) do
    case Keyword.get(opts, :poll_interval, 16) do
      interval when is_integer(interval) and interval > 0 -> interval
      _other -> nil
    end
  end

  defp schedule_poll(%{poll_interval: nil}), do: :ok

  defp schedule_poll(%{poll_interval: interval}) do
    Process.send_after(self(), :poll_display, interval)
    :ok
  end
end
