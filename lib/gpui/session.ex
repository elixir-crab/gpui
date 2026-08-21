defmodule GPUI.Session do
  @moduledoc """
  Renderer-independent state engine for one running `GPUI.Application`.

  A session owns declarative windows, root-view assigns, rendered snapshots,
  resources, strict event dispatch, and atomic callback transitions. It has no
  knowledge of native GPUI, displays, or network transports.

  Ordinary applications should use `GPUI.Runtime`, which composes this state
  engine with a display and synchronization lifecycle. Direct session use is an
  advanced infrastructure boundary for remote hosting, custom runtimes, and
  renderer-independent protocol integration.
  """

  use GenServer

  import GPUI.Event, only: [is_routed_type: 1]

  alias GPUI.Snapshot
  alias GPUI.WindowSpec

  @max_windows 32

  @type operation_error ::
          {:render_failed, term(), Exception.stacktrace()}
          | {:callback_failed, module(), atom(), term(), Exception.stacktrace()}
          | {:invalid_callback_return, module(), atom(), term()}

  @type snapshot :: Snapshot.t()
  @type topology_error ::
          :duplicate_window_key
          | :window_not_found
          | :window_limit_reached
          | {:too_many_windows, pos_integer()}

  @type state :: %{
          windows: [WindowSpec.t()],
          resources: %{optional(String.t()) => map()},
          next_window_id: pos_integer()
        }

  @doc "Starts the renderer-independent state engine linked to the caller."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @doc "Starts a session whose application mount is completed by its supervisor."
  @spec start_link_deferred(keyword()) :: GenServer.on_start()
  def start_link_deferred(opts) do
    GenServer.start_link(__MODULE__, {:deferred, opts})
  end

  @doc "Returns the session's declarative windows."
  @spec windows(GenServer.server()) :: [WindowSpec.t()]
  def windows(session), do: GenServer.call(session, :windows)

  @doc "Adds a keyed declarative window without remounting the application."
  @spec open_window(GenServer.server(), WindowSpec.t()) ::
          {:ok, pos_integer(), snapshot()} | {:error, topology_error()}
  def open_window(session, window), do: GenServer.call(session, {:open_window, window})

  @doc "Removes one declarative window by stable key or native session ID."
  @spec close_window(GenServer.server(), WindowSpec.key() | pos_integer()) ::
          {:ok, snapshot()} | {:error, topology_error()}
  def close_window(session, window), do: GenServer.call(session, {:close_window, window})

  @doc "Returns the current authoritative renderer-independent snapshot."
  @spec snapshot(GenServer.server()) :: snapshot() | {:error, operation_error()}
  def snapshot(session), do: GenServer.call(session, :snapshot)

  @doc "Stores one renderer-independent resource in the next snapshot."
  @spec put_resource(GenServer.server(), String.Chars.t(), map()) :: :ok
  def put_resource(session, id, resource),
    do: GenServer.call(session, {:put_resource, id, resource})

  @doc "Removes one renderer-independent resource from the next snapshot."
  @spec drop_resource(GenServer.server(), String.Chars.t()) :: :ok
  def drop_resource(session, id), do: GenServer.call(session, {:drop_resource, id})

  @doc "Validates and dispatches one display event, returning the handled fact and current snapshot."
  @spec dispatch_event(GenServer.server(), map()) ::
          {:ok, map(), snapshot()} | {:error, operation_error()}
  def dispatch_event(session, event), do: GenServer.call(session, {:dispatch_event, event})

  @doc "Validates and dispatches display events in order, returning handled facts and current snapshot."
  @spec dispatch_events(GenServer.server(), [map()]) ::
          {:ok, [map()], snapshot()} | {:error, operation_error()}
  def dispatch_events(session, events), do: GenServer.call(session, {:dispatch_events, events})

  @doc "Delivers an OTP message to a window's root view."
  @spec send_view(GenServer.server(), pos_integer(), term()) ::
          {:ok, snapshot()} | {:error, :window_not_found | topology_error() | operation_error()}
  def send_view(session, window_id, message),
    do: GenServer.call(session, {:send_view, window_id, message})

  @doc "Rerenders every window with its current module and assigns."
  @spec refresh(GenServer.server()) :: {:ok, snapshot()} | {:error, term()}
  def refresh(session), do: GenServer.call(session, :refresh)

  @doc "Converts a declarative window into its serializable representation."
  @spec window_payload(WindowSpec.t()) :: map()
  def window_payload(%WindowSpec{} = window) do
    %{
      id: window.id,
      key: window.key,
      title: window.title,
      size: Tuple.to_list(window.size || {800, 600}),
      min_size: encode_optional_size(window.min_size),
      resizable: window.resizable,
      chrome: window.chrome,
      lifecycle: window_lifecycle(window.root),
      commands: Enum.map(window.commands, &GPUI.Command.to_payload/1),
      root: encode_root(window.root)
    }
  end

  defp window_lifecycle(nil), do: []

  defp window_lifecycle({module, _assigns}) do
    if function_exported?(module, :handle_window_event, 3),
      do: [:close_request, :focus, :blur],
      else: []
  end

  defp encode_optional_size(nil), do: nil
  defp encode_optional_size(size), do: Tuple.to_list(size)

  @impl GenServer
  def init({:deferred, opts}) do
    app = Keyword.fetch!(opts, :app)
    args = Keyword.get(opts, :args, [])
    {:ok, %{mount: {app, args}}, {:continue, :mount}}
  end

  def init(opts) do
    mount(Keyword.fetch!(opts, :app), Keyword.get(opts, :args, []))
  end

  @impl GenServer
  def handle_continue(:mount, %{mount: {app, args}}) do
    case mount(app, args) do
      {:ok, state} -> {:noreply, state}
      {:stop, reason} -> {:stop, reason, %{mount: {app, args}}}
    end
  end

  @impl GenServer
  def handle_call(:windows, _from, state), do: {:reply, state.windows, state}

  def handle_call(:snapshot, _from, state) do
    case safe_snapshot(state) do
      {:ok, snapshot} -> {:reply, snapshot, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:open_window, %WindowSpec{} = window}, _from, state) do
    case add_window(state, window) do
      {:ok, next_state, id} ->
        case safe_snapshot(next_state) do
          {:ok, snapshot} -> {:reply, {:ok, id, snapshot}, next_state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:close_window, identifier}, _from, state) do
    case pop_window(state.windows, identifier) do
      {nil, _windows} ->
        {:reply, {:error, :window_not_found}, state}

      {_window, windows} ->
        next_state = %{state | windows: windows}

        case safe_snapshot(next_state) do
          {:ok, snapshot} -> {:reply, {:ok, snapshot}, next_state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call(:refresh, _from, state) do
    {:reply, safe_snapshot(state), state}
  end

  def handle_call({:put_resource, id, resource}, _from, state) do
    {:reply, :ok, put_in(state.resources[to_string(id)], resource)}
  end

  def handle_call({:drop_resource, id}, _from, state) do
    {:reply, :ok, update_in(state.resources, &Map.delete(&1, to_string(id)))}
  end

  def handle_call({:dispatch_event, event}, _from, state) do
    {handled, next_state} = normalize_and_handle_event(event, state)
    reply_transition(handled, state, next_state)
  end

  def handle_call({:dispatch_events, events}, _from, state) do
    {handled, next_state} = Enum.map_reduce(events, state, &normalize_and_handle_event/2)
    reply_transition(handled, state, next_state)
  end

  def handle_call({:send_view, window_id, message}, _from, state) do
    case Enum.find(state.windows, &(&1.id == window_id)) do
      %WindowSpec{root: {module, assigns}} = window ->
        assigns = Map.new(assigns)

        with {:ok, result} <-
               safe_callback(module, :handle_info, [message, assigns], {:noreply, assigns}),
             {:ok, next_state} <-
               apply_view_result(result, message, state, window, module, :handle_info),
             {:ok, snapshot} <- safe_snapshot(next_state) do
          {:reply, {:ok, snapshot}, next_state}
        else
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      nil ->
        {:reply, {:error, :window_not_found}, state}
    end
  end

  defp mount(app, args) do
    case app.mount(args) do
      {:ok, windows} when is_list(windows) ->
        case initial_state(windows) do
          {:ok, state} -> {:ok, state}
          {:error, reason} -> {:stop, reason}
        end

      invalid ->
        {:stop, {:invalid_mount_return, invalid}}
    end
  end

  defp initial_state(windows) do
    if length(windows) > @max_windows do
      {:error, {:too_many_windows, @max_windows}}
    else
      windows = assign_window_ids(windows)

      case duplicate_key(windows) do
        nil -> {:ok, new_state(windows)}
        key -> {:error, {:duplicate_window_key, key}}
      end
    end
  end

  defp new_state(windows),
    do: %{windows: windows, resources: %{}, next_window_id: length(windows) + 1}

  defp assign_window_ids(windows) do
    windows
    |> Enum.with_index(1)
    |> Enum.map(fn {%WindowSpec{} = window, id} ->
      window |> WindowSpec.validate!() |> Map.put(:id, id)
    end)
  end

  defp add_window(%{windows: windows} = _state, _window) when length(windows) >= @max_windows,
    do: {:error, :window_limit_reached}

  defp add_window(state, %WindowSpec{} = window) do
    window = WindowSpec.validate!(window)

    if is_binary(window.key) and Enum.any?(state.windows, &(&1.key == window.key)) do
      {:error, :duplicate_window_key}
    else
      id = state.next_window_id
      window = %{window | id: id}
      {:ok, %{state | windows: state.windows ++ [window], next_window_id: id + 1}, id}
    end
  end

  defp duplicate_key(windows) do
    windows
    |> Enum.reject(&is_nil(&1.key))
    |> Enum.frequencies_by(& &1.key)
    |> Enum.find_value(fn {key, count} -> if count > 1, do: key end)
  end

  defp pop_window(windows, identifier) do
    {matched, remaining} =
      Enum.split_with(windows, fn window ->
        if is_integer(identifier), do: window.id == identifier, else: window.key == identifier
      end)

    {List.first(matched), remaining}
  end

  defp safe_snapshot(state) do
    {:ok, snapshot_from_state(state)}
  catch
    kind, reason -> {:error, {:render_failed, normalize_exception(kind, reason), __STACKTRACE__}}
  end

  defp safe_callback(module, callback, arguments, default) do
    if function_exported?(module, callback, length(arguments)) do
      {:ok, apply(module, callback, arguments)}
    else
      {:ok, default}
    end
  catch
    kind, reason ->
      {:error,
       {:callback_failed, module, callback, normalize_exception(kind, reason), __STACKTRACE__}}
  end

  defp normalize_exception(:error, reason), do: reason
  defp normalize_exception(kind, reason), do: {kind, reason}

  defp reply_transition(handled, state, next_state) do
    case transition_error(handled) do
      nil ->
        case safe_snapshot(next_state) do
          {:ok, snapshot} -> {:reply, {:ok, handled, snapshot}, next_state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      reason ->
        {:reply, {:error, reason}, state}
    end
  end

  defp transition_error(events) when is_list(events),
    do: Enum.find_value(events, &transition_error/1)

  defp transition_error(%{error: {kind, _, _, _} = reason})
       when kind in [:callback_failed, :invalid_callback_return],
       do: reason

  defp transition_error(_handled), do: nil

  defp snapshot_from_state(state) do
    %Snapshot{windows: Enum.map(state.windows, &window_payload/1), resources: state.resources}
  end

  defp encode_root(nil), do: nil

  defp encode_root({module, assigns}) do
    assigns = Map.new(assigns)

    %{
      module: inspect(module),
      assigns: assigns,
      tree: viewport(render_root(module, assigns))
    }
  end

  defp viewport(tree) do
    %{
      type: :viewport,
      attrs: %{},
      children: [tree]
    }
  end

  defp render_root(module, assigns) do
    unless Code.ensure_loaded?(module) and function_exported?(module, :render, 1) do
      raise ArgumentError, "window root #{inspect(module)} must implement render/1"
    end

    module.render(assigns)
    |> GPUI.Element.to_payload()
  end

  defp normalize_and_handle_event(event, state) do
    case GPUI.Event.normalize(event) do
      {:ok, event} -> handle_event(event, state)
      {:error, reason} -> {invalid_event(event, reason), state}
    end
  end

  defp invalid_event(event, reason) when is_map(event), do: Map.put(event, :error, reason)
  defp invalid_event(event, reason), do: %{event: event, error: reason}

  defp handle_event(%{type: :window_closed, window_id: window_id} = native_event, state) do
    windows = Enum.reject(state.windows, &(&1.id == window_id))
    {native_event, %{state | windows: windows}}
  end

  defp handle_event(
         %{type: type, window_id: window_id} = native_event,
         state
       )
       when type in [:window_close_request, :window_focus, :window_blur] do
    case Enum.find(state.windows, &(&1.id == window_id)) do
      %WindowSpec{root: {module, assigns}} = window ->
        assigns = Map.new(assigns)
        lifecycle = lifecycle_name(type)

        result =
          if function_exported?(module, :handle_window_event, 3),
            do: module.handle_window_event(lifecycle, native_event, assigns),
            else: {:close, assigns}

        handle_window_result(result, native_event, state, window, module, lifecycle)

      nil ->
        {native_event, state}
    end
  end

  defp handle_event(
         %{type: type, window_id: window_id, event: event} = native_event,
         state
       )
       when is_routed_type(type) do
    case Enum.find(state.windows, &(&1.id == window_id)) do
      %WindowSpec{root: {module, assigns}} = window ->
        assigns = Map.new(assigns)

        with {:ok, result} <-
               safe_callback(module, :handle_event, [event, native_event, assigns], nil),
             {:ok, next_state} <-
               apply_view_result(result, native_event, state, window, module, :handle_event) do
          {native_event, next_state}
        else
          {:error, reason} -> {Map.put(native_event, :error, reason), state}
        end

      nil ->
        {native_event, state}
    end
  end

  defp handle_event(event, state), do: {event, state}

  defp lifecycle_name(:window_close_request), do: :close_request
  defp lifecycle_name(:window_focus), do: :focus
  defp lifecycle_name(:window_blur), do: :blur

  defp handle_window_result(
         {:noreply, assigns},
         event,
         state,
         window,
         module,
         _lifecycle
       )
       when is_map(assigns),
       do: update_window(event, state, window, module, assigns)

  defp handle_window_result({:close, assigns}, event, state, window, module, :close_request)
       when is_map(assigns),
       do: close_window(event, state, window, module, assigns)

  defp handle_window_result(result, event, state, _window, module, _lifecycle) do
    {Map.put(event, :error, {:invalid_callback_return, module, :handle_window_event, result}),
     state}
  end

  defp apply_view_result({:noreply, assigns}, event, state, window, module, _callback)
       when is_map(assigns) do
    {_event, state} = update_window(event, state, window, module, assigns)
    {:ok, state}
  end

  defp apply_view_result({:close, assigns}, event, state, window, module, _callback)
       when is_map(assigns) do
    {_event, state} = close_window(event, state, window, module, assigns)
    {:ok, state}
  end

  defp apply_view_result(
         {:open_window, %WindowSpec{} = opened, assigns},
         event,
         state,
         window,
         module,
         _callback
       )
       when is_map(assigns) do
    case add_window(state, opened) do
      {:ok, state, _id} ->
        {_event, state} = update_window(event, state, window, module, assigns)
        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_view_result(
         {:close_window, identifier, assigns},
         event,
         state,
         window,
         module,
         _callback
       )
       when is_map(assigns) and (is_integer(identifier) or is_binary(identifier)) do
    case pop_window(state.windows, identifier) do
      {nil, _windows} ->
        {:error, :window_not_found}

      {_closed, windows} ->
        state = %{state | windows: windows}
        {_event, state} = update_window(event, state, window, module, assigns)
        {:ok, state}
    end
  end

  defp apply_view_result(result, _event, _state, _window, module, callback),
    do: {:error, {:invalid_callback_return, module, callback, result}}

  defp close_window(event, state, window, _module, _assigns) do
    windows = Enum.reject(state.windows, &(&1.id == window.id))
    {event, %{state | windows: windows}}
  end

  defp update_window(event, state, window, module, assigns) do
    updated = %{window | root: {module, assigns}}
    windows = Enum.map(state.windows, &replace_window(&1, updated))
    {event, %{state | windows: windows}}
  end

  defp replace_window(%WindowSpec{id: id}, %WindowSpec{id: id} = updated), do: updated
  defp replace_window(window, _updated), do: window
end
