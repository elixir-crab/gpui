defmodule GPUI.Remote.DisplayClient do
  @moduledoc """
  Local display-side client for the inverted GPUI remote model.

  It connects to a remote `GPUI.Remote.AppServer`, mounts the remote app, opens
  returned windows on a local display backend, and forwards UI events back to the
  remote app for updated snapshots.
  """

  use GenServer

  alias GPUI.Remote.AppProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  def mount(client, args \\ %{}), do: GenServer.call(client, {:mount, args})
  def event(client, event), do: GenServer.call(client, {:event, event})
  def snapshot(client), do: GenServer.call(client, :snapshot)

  @impl GenServer
  def init(opts) do
    backend = opts |> Keyword.get(:backend, :data) |> GPUI.Backend.module_for()
    backend_opts = Keyword.get(opts, :backend_opts, [])

    with {:ok, app_client} <- start_app_client(opts),
         {:ok, backend_state} <- backend.init(backend_opts) do
      {:ok,
       %{app_client: app_client, backend: backend, backend_state: backend_state, windows: %{}}}
    end
  end

  @impl GenServer
  def handle_call({:mount, args}, _from, state) do
    %{op: op, payload: payload} = AppProtocol.mount(Map.new(args))

    case SafeRPC.call(state.app_client, op, payload) do
      {:ok, %{windows: windows}} ->
        state = sync_windows(state, windows, :open)
        {:reply, {:ok, windows}, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:event, event}, _from, state) do
    %{op: op, payload: payload} = AppProtocol.event(event)

    case SafeRPC.call(state.app_client, op, payload) do
      {:ok, %{windows: windows}} ->
        state = sync_windows(state, windows, :update)
        {:reply, {:ok, windows}, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:snapshot, _from, state) do
    %{op: op, payload: payload} = AppProtocol.snapshot()

    case SafeRPC.call(state.app_client, op, payload) do
      {:ok, %{windows: windows}} ->
        state = sync_windows(state, windows, :update)
        {:reply, {:ok, windows}, state}

      error ->
        {:reply, error, state}
    end
  end

  defp start_app_client(opts) do
    opts
    |> Keyword.put(:transport, SafeRPCTCP)
    |> Keyword.put_new(:cap, AppProtocol.capability())
    |> SafeRPC.Client.start_link()
  end

  defp sync_windows(state, windows, mode) do
    Enum.reduce(windows, state, fn %{id: id} = window, state ->
      sync_window(state, id, window, mode)
    end)
  end

  defp sync_window(state, id, window, :open) do
    :ok = state.backend.open_window(state.backend_state, window)
    put_in(state.windows[id], window)
  end

  defp sync_window(state, id, window, :update) do
    if Map.has_key?(state.windows, id) do
      :ok = state.backend.update_window(state.backend_state, id, get_in(window, [:root, :tree]))
    else
      :ok = state.backend.open_window(state.backend_state, window)
    end

    put_in(state.windows[id], window)
  end
end
