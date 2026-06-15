defmodule GPUI.Remote.DisplayClient do
  @moduledoc """
  Local display-side client for the inverted GPUI remote model.

  It connects to a remote `GPUI.Remote.AppServer`, mounts the remote app, opens
  returned windows on a local display backend, forwards UI events, and reconnects
  on demand by remounting and resynchronizing local windows.
  """

  use GenServer

  alias GPUI.Remote.AppProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  @reconnect_errors [:closed, :timeout, :econnrefused, :enetunreach, :nxdomain]

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
       %{
         opts: opts,
         app_client: app_client,
         backend: backend,
         backend_state: backend_state,
         windows: %{},
         mounted_args: nil,
         session_id: Keyword.get_lazy(opts, :session_id, &new_session_id/0)
       }}
    end
  end

  @impl GenServer
  def handle_call({:mount, args}, _from, state) do
    args = Map.new(args)
    %{op: op, payload: payload} = AppProtocol.mount(Map.put(args, :session_id, state.session_id))

    case call_with_reconnect(state, op, payload) do
      {:ok, %{windows: windows}, state} ->
        state = state |> Map.put(:mounted_args, args) |> sync_windows(windows, :open)
        {:reply, {:ok, windows}, state}

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:event, event}, _from, state) do
    %{op: op, payload: payload} = AppProtocol.event(event)

    case call_with_reconnect(state, op, payload) do
      {:ok, %{windows: windows}, state} ->
        state = sync_windows(state, windows, :update)
        {:reply, {:ok, windows}, state}

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:snapshot, _from, state) do
    %{op: op, payload: payload} = AppProtocol.snapshot()

    case call_with_reconnect(state, op, payload) do
      {:ok, %{windows: windows}, state} ->
        state = sync_windows(state, windows, :update)
        {:reply, {:ok, windows}, state}

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp call_with_reconnect(state, op, payload) do
    case safe_call(state.app_client, op, payload) do
      {:ok, reply} ->
        {:ok, reply, state}

      {:error, reason} ->
        if reconnectable?(reason) do
          case reconnect(state) do
            {:ok, state} -> retry_after_reconnect(state, op, payload)
            {:error, reconnect_reason, state} -> {:error, reconnect_reason, state}
          end
        else
          {:error, reason, state}
        end
    end
  end

  defp retry_after_reconnect(state, op, payload) do
    case safe_call(state.app_client, op, payload) do
      {:ok, reply} -> {:ok, reply, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp reconnect(state) do
    stop_client(state.app_client)

    case start_app_client(state.opts) do
      {:ok, app_client} -> remount_if_needed(%{state | app_client: app_client})
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp remount_if_needed(%{mounted_args: nil} = state), do: {:ok, state}

  defp remount_if_needed(state) do
    case resume_session(state) do
      {:ok, state} -> {:ok, state}
      {:error, _reason, state} -> remount(state)
    end
  end

  defp resume_session(state) do
    %{op: op, payload: payload} = AppProtocol.resume_session(state.session_id)

    case safe_call(state.app_client, op, payload) do
      {:ok, %{windows: windows}} -> {:ok, sync_windows(state, windows, :update)}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp remount(%{mounted_args: args} = state) do
    %{op: op, payload: payload} = AppProtocol.mount(Map.put(args, :session_id, state.session_id))

    case safe_call(state.app_client, op, payload) do
      {:ok, %{windows: windows}} -> {:ok, sync_windows(state, windows, :update)}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp safe_call(client, op, payload) do
    SafeRPC.call(client, op, payload)
  catch
    :exit, {:noproc, _} -> {:error, :closed}
    :exit, {:normal, _} -> {:error, :closed}
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp reconnectable?(reason) when reason in @reconnect_errors, do: true
  defp reconnectable?({:exit, _reason}), do: true
  defp reconnectable?(_reason), do: false

  defp stop_client(nil), do: :ok

  defp stop_client(client) when is_pid(client) do
    if Process.alive?(client), do: GenServer.stop(client)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp new_session_id do
    System.unique_integer([:positive, :monotonic])
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
