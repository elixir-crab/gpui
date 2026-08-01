defmodule GPUI.Session do
  @moduledoc """
  Renderer-independent owner of one running `GPUI.Application`.

  A session owns declarative windows, root-view assigns, rendered snapshots, and
  resources. It has no knowledge of native GPUI, displays, or network transports.
  """

  use GenServer

  alias GPUI.Snapshot
  alias GPUI.WindowSpec

  @type snapshot :: Snapshot.t()

  @type state :: %{
          windows: [WindowSpec.t()],
          resources: %{optional(String.t()) => map()}
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @doc false
  @spec start_link_deferred(keyword()) :: GenServer.on_start()
  def start_link_deferred(opts) do
    GenServer.start_link(__MODULE__, {:deferred, opts})
  end

  @spec windows(GenServer.server()) :: [WindowSpec.t()]
  def windows(session), do: GenServer.call(session, :windows)

  @spec snapshot(GenServer.server()) :: snapshot()
  def snapshot(session), do: GenServer.call(session, :snapshot)

  @spec put_resource(GenServer.server(), String.Chars.t(), map()) :: :ok
  def put_resource(session, id, resource),
    do: GenServer.call(session, {:put_resource, id, resource})

  @spec drop_resource(GenServer.server(), String.Chars.t()) :: :ok
  def drop_resource(session, id), do: GenServer.call(session, {:drop_resource, id})

  @spec dispatch_event(GenServer.server(), map()) :: {map(), snapshot()}
  def dispatch_event(session, event), do: GenServer.call(session, {:dispatch_event, event})

  @spec dispatch_events(GenServer.server(), [map()]) :: {[map()], snapshot()}
  def dispatch_events(session, events), do: GenServer.call(session, {:dispatch_events, events})

  @doc "Delivers an OTP message to a window's root view."
  @spec send_view(GenServer.server(), pos_integer(), term()) ::
          {:ok, snapshot()} | {:error, :window_not_found}
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
      title: window.title,
      size: Tuple.to_list(window.size || {800, 600}),
      commands: Enum.map(window.commands, &GPUI.Command.to_payload/1),
      root: encode_root(window.root)
    }
  end

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

  def handle_call(:snapshot, _from, state), do: {:reply, snapshot_from_state(state), state}

  def handle_call(:refresh, _from, state) do
    reply =
      try do
        {:ok, snapshot_from_state(state)}
      catch
        :error, reason when is_exception(reason) ->
          {:error, {:render_failed, reason, __STACKTRACE__}}

        kind, reason ->
          {:error, {:render_failed, {kind, reason}, __STACKTRACE__}}
      end

    {:reply, reply, state}
  end

  def handle_call({:put_resource, id, resource}, _from, state) do
    {:reply, :ok, put_in(state.resources[to_string(id)], resource)}
  end

  def handle_call({:drop_resource, id}, _from, state) do
    {:reply, :ok, update_in(state.resources, &Map.delete(&1, to_string(id)))}
  end

  def handle_call({:dispatch_event, event}, _from, state) do
    {handled, state} = event |> GPUI.Event.normalize() |> handle_event(state)
    {:reply, {handled, snapshot_from_state(state)}, state}
  end

  def handle_call({:dispatch_events, events}, _from, state) do
    {handled, state} =
      Enum.map_reduce(events, state, fn event, state ->
        event |> GPUI.Event.normalize() |> handle_event(state)
      end)

    {:reply, {handled, snapshot_from_state(state)}, state}
  end

  def handle_call({:send_view, window_id, message}, _from, state) do
    case Enum.find(state.windows, &(&1.id == window_id)) do
      %WindowSpec{root: {module, assigns}} = window ->
        assigns = Map.new(assigns)

        result =
          if function_exported?(module, :handle_info, 2),
            do: module.handle_info(message, assigns),
            else: {:noreply, assigns}

        case result do
          {:noreply, new_assigns} when is_map(new_assigns) ->
            {_message, state} = update_window(message, state, window, module, new_assigns)
            {:reply, {:ok, snapshot_from_state(state)}, state}

          invalid ->
            raise ArgumentError,
                  "#{inspect(module)}.handle_info/2 returned #{inspect(invalid)}; " <>
                    "expected {:noreply, assigns}"
        end

      nil ->
        {:reply, {:error, :window_not_found}, state}
    end
  end

  defp mount(app, args) do
    case app.mount(args) do
      {:ok, windows} when is_list(windows) ->
        {:ok, new_state(assign_window_ids(windows))}

      invalid ->
        {:stop, {:invalid_mount_return, invalid}}
    end
  end

  defp new_state(windows), do: %{windows: windows, resources: %{}}

  defp assign_window_ids(windows) do
    windows
    |> Enum.with_index(1)
    |> Enum.map(fn {%WindowSpec{} = window, id} ->
      window |> WindowSpec.validate!() |> Map.put(:id, id)
    end)
  end

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

  defp handle_event(%{type: :window_closed, window_id: window_id} = native_event, state) do
    windows = Enum.reject(state.windows, &(&1.id == window_id))
    {native_event, %{state | windows: windows}}
  end

  defp handle_event(
         %{type: type, window_id: window_id, event: event} = native_event,
         state
       )
       when type in [
              :click,
              :command,
              :change,
              :select,
              :release,
              :search,
              :submit,
              :range,
              :transaction,
              :selection,
              :viewport,
              :geometry,
              :range_geometry,
              :hit_test,
              :bounds,
              :focus,
              :blur,
              :keydown,
              :keyup
            ] do
    case Enum.find(state.windows, &(&1.id == window_id)) do
      %WindowSpec{root: {module, assigns}} = window ->
        assigns = Map.new(assigns)

        case module.handle_event(event, native_event, assigns) do
          {:noreply, new_assigns} when is_map(new_assigns) ->
            update_window(native_event, state, window, module, new_assigns)

          {:reply, _reply, new_assigns} when is_map(new_assigns) ->
            update_window(native_event, state, window, module, new_assigns)

          invalid ->
            raise ArgumentError,
                  "#{inspect(module)}.handle_event/3 returned #{inspect(invalid)}; " <>
                    "expected {:noreply, assigns} or {:reply, reply, assigns}"
        end

      nil ->
        {native_event, state}
    end
  end

  defp handle_event(event, state), do: {event, state}

  defp update_window(event, state, window, module, assigns) do
    updated = %{window | root: {module, assigns}}
    windows = Enum.map(state.windows, &replace_window(&1, updated))
    {event, %{state | windows: windows}}
  end

  defp replace_window(%WindowSpec{id: id}, %WindowSpec{id: id} = updated), do: updated
  defp replace_window(window, _updated), do: window
end
