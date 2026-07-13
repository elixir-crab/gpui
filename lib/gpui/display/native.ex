defmodule GPUI.Display.Native do
  @moduledoc """
  Local display backed by the native Rust GPUI runtime.

  A display owns one native runtime namespace while sharing the process-global
  GPUI application loop with other native displays.
  """

  use GenServer

  @behaviour GPUI.Display

  @impl GPUI.Display
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @impl GPUI.Display
  def sync(display, snapshot), do: GenServer.call(display, {:sync, snapshot})

  @impl GPUI.Display
  def drain_events(display), do: GenServer.call(display, :drain_events)

  @impl GPUI.Display
  def inject_event(display, event), do: GenServer.call(display, {:inject_event, event})

  @impl GenServer
  def init(_opts) do
    case GPUI.Native.start_runtime() do
      {:ok, runtime} -> {:ok, %{runtime: runtime, windows: MapSet.new(), resources: %{}}}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    GPUI.Native.stop_runtime(state.runtime)
    :ok
  catch
    :error, _reason -> :ok
    :exit, _reason -> :ok
  end

  @impl GenServer
  def handle_call({:sync, snapshot}, _from, state) do
    case sync_snapshot(state, snapshot) do
      {:ok, state} -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:drain_events, _from, state) do
    case GPUI.Native.drain_events(state.runtime) do
      {:ok, events} -> {:reply, {:ok, events}, forget_closed_windows(state, events)}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:inject_event, event}, _from, state) do
    {:reply, GPUI.Native.inject_event(state.runtime, event), state}
  end

  defp forget_closed_windows(state, events) do
    closed_ids =
      for %{type: :window_closed, window_id: window_id} <- events,
          into: MapSet.new(),
          do: window_id

    %{state | windows: MapSet.difference(state.windows, closed_ids)}
  end

  defp sync_snapshot(state, %{windows: windows, resources: resources}) do
    case sync_resources(state, resources) do
      {:ok, state} -> sync_windows(state, windows)
      {:error, reason} -> {:error, reason}
    end
  end

  defp sync_resources(state, resources) do
    removed_ids = Map.keys(state.resources) -- Map.keys(resources)

    with :ok <- each_ok(removed_ids, &drop_resource(state.runtime, &1)),
         :ok <-
           each_ok(
             changed_resources(state.resources, resources),
             &put_resource(state.runtime, &1)
           ) do
      {:ok, %{state | resources: resources}}
    end
  end

  defp changed_resources(previous, resources) do
    Enum.reject(resources, fn {id, resource} -> Map.get(previous, id) == resource end)
  end

  defp put_resource(runtime, {id, resource}) do
    case GPUI.Native.put_resource(runtime, to_string(id), resource) do
      {:ok, _id} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp drop_resource(runtime, id) do
    case GPUI.Native.drop_resource(runtime, to_string(id)) do
      {:ok, _id} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp sync_windows(state, windows) do
    desired = MapSet.new(windows, & &1.id)
    removed = MapSet.difference(state.windows, desired)

    with :ok <- each_ok(removed, &close_window(state.runtime, &1)),
         :ok <- each_ok(windows, &sync_window(state, &1)) do
      {:ok, %{state | windows: desired}}
    end
  end

  defp close_window(runtime, window_id) do
    case GPUI.Native.close_window(runtime, window_id) do
      {:ok, ^window_id} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp sync_window(state, %{id: id} = window) do
    result =
      if MapSet.member?(state.windows, id) do
        GPUI.Native.update_window(state.runtime, id, get_in(window, [:root, :tree]))
      else
        GPUI.Native.open_window(state.runtime, window)
      end

    case result do
      {:ok, _value} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp each_ok(values, fun) do
    Enum.reduce_while(values, :ok, fn value, :ok ->
      case fun.(value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
