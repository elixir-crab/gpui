defmodule GPUI.Runtime do
  @moduledoc """
  Local composition of a renderer-independent `GPUI.Session` and a display.

  The runtime synchronizes session snapshots to the display and routes display
  events back into the session. Remote application servers use `GPUI.Session`
  directly and therefore never start a native display.
  """

  use GenServer

  @call_timeout 5_000
  @event_history_limit 1_000

  @type state :: %{
          session: pid(),
          display: pid(),
          display_module: module(),
          events: [map()],
          poll_interval: pos_integer() | nil
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
        poll_interval: poll_interval(opts)
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

  def handle_call({:put_resource, id, resource}, _from, state) do
    :ok = GPUI.Session.put_resource(state.session, id, resource)
    reply = sync_display(state)
    {:reply, reply, state}
  end

  def handle_call({:drop_resource, id}, _from, state) do
    :ok = GPUI.Session.drop_resource(state.session, id)
    reply = sync_display(state)
    {:reply, reply, state}
  end

  def handle_call({:dispatch_event, event}, _from, state) do
    {handled, snapshot} = GPUI.Session.dispatch_event(state.session, event)
    :ok = state.display_module.sync(state.display, snapshot)
    {:reply, {handled, snapshot}, state}
  end

  def handle_call(:drain_events, _from, state) do
    {handled, state} = drain_display_events(state)
    {:reply, handled, state}
  end

  def handle_call({:inject_event, event}, _from, state) do
    {:reply, state.display_module.inject_event(state.display, event), state}
  end

  @impl GenServer
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

    if events != [], do: :ok = state.display_module.sync(state.display, snapshot)
    {handled, state}
  end

  defp sync_display(state) do
    state.display_module.sync(state.display, GPUI.Session.snapshot(state.session))
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
