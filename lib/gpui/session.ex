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

  @doc "Converts a declarative window into its serializable representation."
  @spec window_payload(WindowSpec.t()) :: map()
  def window_payload(%WindowSpec{} = window) do
    %{
      id: window.id,
      title: window.title,
      size: Tuple.to_list(window.size || {800, 600}),
      root: encode_root(window.root)
    }
  end

  @impl GenServer
  def init(opts) do
    app = Keyword.fetch!(opts, :app)
    args = Keyword.get(opts, :args, [])

    case app.mount(args) do
      {:ok, windows} when is_list(windows) ->
        {:ok, new_state(assign_window_ids(windows))}
    end
  end

  @impl GenServer
  def handle_call(:windows, _from, state), do: {:reply, state.windows, state}

  def handle_call(:snapshot, _from, state), do: {:reply, snapshot_from_state(state), state}

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
      tree: render_root(module, assigns)
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
       when type in [:click, :change, :select, :release, :search, :keydown, :keyup] do
    case Enum.find(state.windows, &(&1.id == window_id)) do
      %WindowSpec{root: {module, assigns}} = window ->
        assigns = Map.new(assigns)

        case module.handle_event(event, native_event, assigns) do
          {:noreply, new_assigns} ->
            update_window(native_event, state, window, module, new_assigns)

          {:reply, _reply, new_assigns} ->
            update_window(native_event, state, window, module, new_assigns)
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
