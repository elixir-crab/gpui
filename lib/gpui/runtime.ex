defmodule GPUI.Runtime do
  @moduledoc """
  OTP owner for a GPUI application runtime.

  The runtime owns application state and rendered window specs. Concrete IO is
  delegated to a real `GPUI.Backend` implementation: local native windows or
  SafeRPC/TCP remote display transport.
  """

  use GenServer

  alias GPUI.WindowSpec

  @type state :: %{
          app: module(),
          app_state: term(),
          windows: [WindowSpec.t()],
          backend: module(),
          backend_state: GPUI.Backend.state(),
          backend_messages: [map()],
          poll_interval: pos_integer() | nil,
          resources: %{optional(term()) => map()}
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    app = Keyword.fetch!(opts, :app)
    GenServer.start_link(__MODULE__, opts, name: app)
  end

  @impl GenServer
  def init(opts) do
    app = Keyword.fetch!(opts, :app)
    args = Keyword.get(opts, :args, [])
    backend = opts |> Keyword.get(:backend, :native) |> GPUI.Backend.module_for()

    with {:ok, backend_state} <- backend.init(opts) do
      case app.mount(args) do
        {:ok, app_state} ->
          state = initial_state(app, app_state, [], backend, backend_state, poll_interval(opts))
          schedule_backend_poll(state)
          {:ok, state}

        {:ok, app_state, windows} when is_list(windows) ->
          windows = assign_window_ids(windows)

          state =
            initial_state(app, app_state, windows, backend, backend_state, poll_interval(opts))

          Enum.each(windows, &sync_window(state, &1))
          schedule_backend_poll(state)
          {:ok, state}
      end
    end
  end

  @doc "Returns declared windows for tests and future backend synchronization."
  @spec windows(GenServer.server()) :: [WindowSpec.t()]
  def windows(server), do: GenServer.call(server, :windows)

  @doc "Returns replies/events received from the backend."
  @spec backend_messages(GenServer.server()) :: [map()]
  def backend_messages(server), do: GenServer.call(server, :backend_messages)

  @doc "Drains backend events, applies view callbacks, and syncs updated views."
  @spec drain_events(GenServer.server()) :: [map()]
  def drain_events(server), do: GenServer.call(server, :drain_events)

  @doc "Stores a display resource through the active backend."
  @spec put_resource(GenServer.server(), term(), map()) :: :ok | {:error, term()}
  def put_resource(server, resource_id, resource),
    do: GenServer.call(server, {:put_resource, resource_id, resource})

  @doc "Drops a display resource through the active backend."
  @spec drop_resource(GenServer.server(), term()) :: :ok | {:error, term()}
  def drop_resource(server, resource_id),
    do: GenServer.call(server, {:drop_resource, resource_id})

  @doc "Dispatches a normalized UI event directly into the runtime."
  @spec dispatch_event(GenServer.server(), map()) :: {map(), [map()]}
  def dispatch_event(server, event), do: GenServer.call(server, {:dispatch_event, event})

  @doc "Injects a normalized backend event through the active backend."
  @spec inject_event(GenServer.server(), map()) :: {:ok, term()} | {:error, term()}
  def inject_event(server, event), do: GenServer.call(server, {:inject_event, event})

  @impl GenServer
  def handle_call(:windows, _from, state) do
    {:reply, state.windows, state}
  end

  @impl GenServer
  def handle_call(:backend_messages, _from, state) do
    {:ok, events} = state.backend.drain_events(state.backend_state)

    backend_messages =
      Enum.map(events, &%{op: :backend_event, payload: normalize_backend_event(&1)})

    {:reply, Enum.reverse(state.backend_messages, backend_messages), state}
  end

  @impl GenServer
  def handle_call({:put_resource, resource_id, resource}, _from, state) do
    case state.backend.put_resource(state.backend_state, resource_id, resource) do
      :ok -> {:reply, :ok, put_in(state.resources[resource_id], resource)}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:drop_resource, resource_id}, _from, state) do
    case state.backend.drop_resource(state.backend_state, resource_id) do
      :ok -> {:reply, :ok, update_in(state.resources, &Map.delete(&1, resource_id))}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:dispatch_event, event}, _from, state) do
    event = normalize_backend_event(event)
    {handled, state} = handle_backend_event(event, state)
    {:reply, {handled, window_payloads(state)}, state}
  end

  @impl GenServer
  def handle_call(:drain_events, _from, state) do
    {handled, state} = drain_backend_events(state)
    {:reply, handled, state}
  end

  @impl GenServer
  def handle_call({:inject_event, event}, _from, state) do
    {:reply, state.backend.inject_event(state.backend_state, event), state}
  end

  @impl GenServer
  def handle_info(:poll_backend_events, state) do
    {handled, state} = drain_backend_events(state)

    state =
      handled
      |> Enum.map(&%{op: :backend_event, payload: &1})
      |> prepend_backend_messages(state)

    schedule_backend_poll(state)
    {:noreply, state}
  end

  def handle_info(message, state) do
    case state.backend.handle_info(state.backend_state, message) do
      {:ok, %{type: type} = event} when type in [:click, :change, :keydown, :keyup] ->
        {handled, state} = handle_backend_event(event, state)
        {:noreply, prepend_backend_messages([%{op: :backend_event, payload: handled}], state)}

      {:ok, event} ->
        {:noreply, %{state | backend_messages: [event | state.backend_messages]}}

      :unhandled ->
        {:noreply, state}
    end
  end

  defp initial_state(app, app_state, windows, backend, backend_state, poll_interval) do
    %{
      app: app,
      app_state: app_state,
      windows: windows,
      backend: backend,
      backend_state: backend_state,
      backend_messages: [],
      poll_interval: poll_interval,
      resources: %{}
    }
  end

  defp poll_interval(opts) do
    case Keyword.get(opts, :poll_interval) do
      interval when is_integer(interval) and interval > 0 -> interval
      _interval -> nil
    end
  end

  defp schedule_backend_poll(%{poll_interval: nil}), do: :ok

  defp schedule_backend_poll(%{poll_interval: interval}) do
    Process.send_after(self(), :poll_backend_events, interval)
    :ok
  end

  defp assign_window_ids(windows) do
    windows
    |> Enum.with_index(1)
    |> Enum.map(fn {%WindowSpec{} = window, id} -> %{window | id: id} end)
  end

  defp sync_window(state, %WindowSpec{} = window) do
    :ok = state.backend.open_window(state.backend_state, window_payload(state, window))
  end

  defp window_payloads(state), do: Enum.map(state.windows, &window_payload(state, &1))

  defp update_window(state, %WindowSpec{} = window) do
    :ok =
      state.backend.update_window(
        state.backend_state,
        window.id,
        window_payload(state, window).root.tree
      )
  end

  @doc false
  @spec window_payload(WindowSpec.t()) :: map()
  def window_payload(%WindowSpec{} = window) do
    %{
      id: window.id,
      title: window.title,
      size: Tuple.to_list(window.size || {800, 600}),
      root: encode_root(window.root)
    }
  end

  defp window_payload(%{backend: GPUI.Backend.Native}, %WindowSpec{} = window) do
    window_payload(window)
  end

  defp window_payload(state, %WindowSpec{} = window) do
    window
    |> window_payload()
    |> resolve_resource_refs(state.resources)
  end

  defp resolve_resource_refs(%GPUI.ResourceRef{} = ref, resources) do
    resolve_resource_refs(GPUI.ResourceRef.to_payload(ref), resources)
  end

  defp resolve_resource_refs(%{__type__: :resource_ref, id: id}, resources) do
    Map.get(resources, id, %{__type__: :missing_resource, id: id})
  end

  defp resolve_resource_refs(%{} = map, resources) do
    Map.new(map, fn {key, value} -> {key, resolve_resource_refs(value, resources)} end)
  end

  defp resolve_resource_refs(values, resources) when is_list(values) do
    Enum.map(values, &resolve_resource_refs(&1, resources))
  end

  defp resolve_resource_refs(value, _resources), do: value

  defp encode_root(nil), do: nil

  defp encode_root({module, assigns}) do
    assigns = Map.new(assigns)

    %{
      module: inspect(module),
      assigns: assigns,
      tree: render_root(module, assigns)
    }
  end

  defp render_root(module, assigns) do
    if function_exported?(module, :render, 1) do
      module.render(assigns)
      |> GPUI.Element.to_payload()
    else
      nil
    end
  end

  defp normalize_backend_event(event) when is_list(event), do: Map.new(event)
  defp normalize_backend_event(event), do: event

  defp drain_backend_events(state) do
    {:ok, events} = state.backend.drain_events(state.backend_state)

    events
    |> Enum.map(&normalize_backend_event/1)
    |> Enum.map_reduce(state, &handle_backend_event/2)
  end

  defp handle_backend_event(
         %{type: type, window_id: window_id, event: event} = backend_event,
         state
       )
       when type in [:click, :change, :keydown, :keyup] do
    case Enum.find(state.windows, &(&1.id == window_id)) do
      %WindowSpec{root: {module, assigns}} = window ->
        assigns = Map.new(assigns)

        case module.handle_event(event, backend_event, assigns) do
          {:noreply, new_assigns} ->
            updated_window = %{window | root: {module, new_assigns}}
            update_window(state, updated_window)
            {backend_event, %{state | windows: replace_window(state.windows, updated_window)}}

          {:reply, _reply, new_assigns} ->
            updated_window = %{window | root: {module, new_assigns}}
            update_window(state, updated_window)
            {backend_event, %{state | windows: replace_window(state.windows, updated_window)}}
        end

      nil ->
        {backend_event, state}
    end
  end

  defp handle_backend_event(event, state), do: {event, state}

  defp prepend_backend_messages([], state), do: state

  defp prepend_backend_messages(messages, state) do
    %{state | backend_messages: Enum.reverse(messages, state.backend_messages)}
  end

  defp replace_window(windows, updated_window) do
    Enum.map(windows, fn
      %WindowSpec{id: id} when id == updated_window.id -> updated_window
      window -> window
    end)
  end
end
