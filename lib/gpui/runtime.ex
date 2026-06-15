defmodule GPUI.Runtime do
  @moduledoc """
  OTP owner for a GPUI backend.
  """

  use GenServer

  alias GPUI.WindowSpec

  @type state :: %{
          app: module(),
          app_state: term(),
          windows: [WindowSpec.t()],
          host: port() | nil,
          native: term() | nil,
          host_messages: [map()],
          poll_interval: pos_integer() | nil
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

    host = start_host(opts)
    native = start_native(opts)

    case app.mount(args) do
      {:ok, app_state} ->
        state = initial_state(app, app_state, [], host, native, poll_interval(opts))
        schedule_native_poll(state)
        {:ok, state}

      {:ok, app_state, windows} when is_list(windows) ->
        windows = assign_window_ids(windows)
        Enum.each(windows, &sync_window(host, native, &1))
        state = initial_state(app, app_state, windows, host, native, poll_interval(opts))
        schedule_native_poll(state)
        {:ok, state}
    end
  end

  @doc "Returns declared windows for tests and future backend synchronization."
  @spec windows(GenServer.server()) :: [WindowSpec.t()]
  def windows(server), do: GenServer.call(server, :windows)

  @doc "Returns replies/events received from the Rust host/native runtime."
  @spec host_messages(GenServer.server()) :: [map()]
  def host_messages(server), do: GenServer.call(server, :host_messages)

  @doc "Drains native events, applies view callbacks, and syncs updated views."
  @spec drain_events(GenServer.server()) :: [map()]
  def drain_events(server), do: GenServer.call(server, :drain_events)

  @impl GenServer
  def handle_call(:windows, _from, state) do
    {:reply, state.windows, state}
  end

  @impl GenServer
  def handle_call(:host_messages, _from, %{native: nil} = state) do
    {:reply, Enum.reverse(state.host_messages), state}
  end

  def handle_call(:host_messages, _from, %{native: native} = state) do
    {:ok, events} = GPUI.Native.drain_events(native)
    native_messages = Enum.map(events, &%{op: :native_event, payload: normalize_native_event(&1)})
    {:reply, Enum.reverse(state.host_messages) ++ native_messages, state}
  end

  @impl GenServer
  def handle_call(:drain_events, _from, %{native: nil} = state) do
    {:reply, [], state}
  end

  def handle_call(:drain_events, _from, %{native: native} = state) do
    {handled, state} = drain_native_events(native, state)
    {:reply, handled, state}
  end

  @impl GenServer
  def handle_info(:poll_native_events, %{native: native} = state) when not is_nil(native) do
    {handled, state} = drain_native_events(native, state)

    state =
      handled
      |> Enum.map(&%{op: :native_event, payload: &1})
      |> prepend_host_messages(state)

    schedule_native_poll(state)
    {:noreply, state}
  end

  def handle_info(:poll_native_events, state) do
    schedule_native_poll(state)
    {:noreply, state}
  end

  def handle_info({host, {:data, payload}}, %{host: host} = state) do
    message = GPUI.Protocol.decode(payload)
    {:noreply, %{state | host_messages: [message | state.host_messages]}}
  end

  @impl GenServer
  def handle_info({host, {:exit_status, status}}, %{host: host} = state) do
    message = %{op: :host_exit, status: status}
    {:noreply, %{state | host: nil, host_messages: [message | state.host_messages]}}
  end

  defp initial_state(app, app_state, windows, host, native, poll_interval) do
    %{
      app: app,
      app_state: app_state,
      windows: windows,
      host: host,
      native: native,
      host_messages: [],
      poll_interval: poll_interval
    }
  end

  defp poll_interval(opts) do
    case Keyword.get(opts, :poll_interval) do
      interval when is_integer(interval) and interval > 0 -> interval
      _interval -> nil
    end
  end

  defp schedule_native_poll(%{native: nil}), do: :ok
  defp schedule_native_poll(%{poll_interval: nil}), do: :ok

  defp schedule_native_poll(%{poll_interval: interval}) do
    Process.send_after(self(), :poll_native_events, interval)
    :ok
  end

  defp assign_window_ids(windows) do
    windows
    |> Enum.with_index(1)
    |> Enum.map(fn {%WindowSpec{} = window, id} -> %{window | id: id} end)
  end

  defp start_host(opts) do
    case Keyword.get(opts, :backend, :data) do
      :host -> GPUI.Host.start_link(opts)
      _backend -> nil
    end
  end

  defp start_native(opts) do
    case Keyword.get(opts, :backend, :data) do
      :native ->
        {:ok, runtime} = GPUI.Native.start_runtime()
        runtime

      _backend ->
        nil
    end
  end

  defp sync_window(nil, nil, %WindowSpec{}), do: :ok

  defp sync_window(host, nil, %WindowSpec{} = window) when is_port(host) do
    GPUI.Host.command(host, GPUI.Protocol.command(:open_window, window_payload(window)))
  end

  defp sync_window(nil, native, %WindowSpec{} = window) do
    {:ok, _title} = GPUI.Native.open_window(native, window_payload(window))
    :ok
  end

  defp update_window(nil, %WindowSpec{}), do: :ok

  defp update_window(native, %WindowSpec{} = window) do
    {:ok, _} = GPUI.Native.update_window(native, window.id, window_payload(window).root.tree)
    :ok
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
      module
      |> apply(:render, [assigns])
      |> GPUI.Element.to_payload()
    else
      nil
    end
  end

  defp normalize_native_event(event) when is_list(event), do: Map.new(event)
  defp normalize_native_event(event), do: event

  defp drain_native_events(native, state) do
    {:ok, events} = GPUI.Native.drain_events(native)

    events
    |> Enum.map(&normalize_native_event/1)
    |> Enum.map_reduce(state, &handle_native_event/2)
  end

  defp handle_native_event(
         %{type: :click, window_id: window_id, event: event} = native_event,
         state
       ) do
    case Enum.find(state.windows, &(&1.id == window_id)) do
      %WindowSpec{root: {module, assigns}} = window ->
        assigns = Map.new(assigns)

        case module.handle_event(event, native_event, assigns) do
          {:noreply, new_assigns} ->
            updated_window = %{window | root: {module, new_assigns}}
            update_window(state.native, updated_window)
            {native_event, %{state | windows: replace_window(state.windows, updated_window)}}

          {:reply, _reply, new_assigns} ->
            updated_window = %{window | root: {module, new_assigns}}
            update_window(state.native, updated_window)
            {native_event, %{state | windows: replace_window(state.windows, updated_window)}}
        end

      nil ->
        {native_event, state}
    end
  end

  defp handle_native_event(event, state), do: {event, state}

  defp prepend_host_messages([], state), do: state

  defp prepend_host_messages(messages, state) do
    %{state | host_messages: Enum.reverse(messages) ++ state.host_messages}
  end

  defp replace_window(windows, updated_window) do
    Enum.map(windows, fn
      %WindowSpec{id: id} when id == updated_window.id -> updated_window
      window -> window
    end)
  end
end
