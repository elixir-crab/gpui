defmodule GPUI.Backend.RemoteTCP.Session do
  @moduledoc false

  use GenServer

  alias GPUI.Remote.DisplayProtocol
  alias GPUI.Remote.Transport.SafeRPC.TCP, as: SafeRPCTCP

  @reconnect_errors [:closed, :timeout, :econnrefused, :enetunreach, :nxdomain]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def open_window(session, window_payload),
    do: GenServer.call(session, {:open_window, window_payload})

  def update_window(session, window_id, tree),
    do: GenServer.call(session, {:update_window, window_id, tree})

  def put_resource(session, resource_id, resource),
    do: GenServer.call(session, {:put_resource, resource_id, resource})

  def drop_resource(session, resource_id),
    do: GenServer.call(session, {:drop_resource, resource_id})

  def drain_events(session), do: GenServer.call(session, :drain_events)
  def emit_test_event(session, event), do: GenServer.call(session, {:emit_test_event, event})

  @impl GenServer
  def init(opts) do
    session_id = Keyword.get_lazy(opts, :session_id, &new_session_id/0)

    state = %{
      opts: opts,
      client: nil,
      session_id: session_id,
      windows: %{},
      resources: %{}
    }

    case connect(state) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:open_window, window_payload}, _from, state) do
    %{op: op, payload: payload} = DisplayProtocol.open_window(window_payload)

    case call_with_reconnect(state, op, payload) do
      {:ok, _reply, state} ->
        {:reply, :ok, put_window(state, window_payload)}

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_window, window_id, tree}, _from, state) do
    %{op: op, payload: payload} = DisplayProtocol.update_window(window_id, tree)

    case call_with_reconnect(state, op, payload) do
      {:ok, _reply, state} ->
        {:reply, :ok, put_window_tree(state, window_id, tree)}

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:put_resource, resource_id, resource}, _from, state) do
    %{op: op, payload: payload} = DisplayProtocol.put_resource(resource_id, resource)

    case call_with_reconnect(state, op, payload) do
      {:ok, _reply, state} -> {:reply, :ok, put_resource_state(state, resource_id, resource)}
      {:error, reason, state} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:drop_resource, resource_id}, _from, state) do
    %{op: op, payload: payload} = DisplayProtocol.drop_resource(resource_id)

    case call_with_reconnect(state, op, payload) do
      {:ok, _reply, state} -> {:reply, :ok, drop_resource_state(state, resource_id)}
      {:error, reason, state} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:drain_events, _from, state) do
    %{op: op, payload: payload} = DisplayProtocol.drain_events()

    case call_with_reconnect(state, op, payload) do
      {:ok, %{events: events}, state} -> {:reply, {:ok, events}, state}
      {:error, reason, state} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:emit_test_event, event}, _from, state) do
    %{op: op, payload: payload} = event |> normalize_test_event() |> DisplayProtocol.event()

    case call_with_reconnect(state, op, payload) do
      {:ok, reply, state} -> {:reply, {:ok, reply}, state}
      {:error, reason, state} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def terminate(_reason, %{client: client}) when is_pid(client) do
    if Process.alive?(client), do: GenServer.stop(client)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp connect(state) do
    opts =
      state.opts
      |> Keyword.put(:transport, SafeRPCTCP)
      |> Keyword.put_new(:cap, DisplayProtocol.capability())

    with {:ok, client} <- SafeRPC.Client.start_link(opts),
         state = %{state | client: client},
         {:ok, state} <- hello(state),
         {:ok, state} <- resume_session(state),
         {:ok, state} <- replay_resources(state) do
      replay_windows(state)
    end
  end

  defp hello(state) do
    %{op: op, payload: payload} = DisplayProtocol.hello()

    case safe_call(state.client, state.session_id, op, payload) do
      {:ok, _hello} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resume_session(state) do
    %{op: op, payload: payload} = DisplayProtocol.resume_session(state.session_id)

    case safe_call(state.client, state.session_id, op, payload) do
      {:ok, _session} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp replay_resources(state) do
    Enum.reduce_while(state.resources, {:ok, state}, fn {resource_id, resource}, {:ok, state} ->
      %{op: op, payload: payload} = DisplayProtocol.put_resource(resource_id, resource)

      case safe_call(state.client, state.session_id, op, payload) do
        {:ok, _reply} -> {:cont, {:ok, state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp replay_windows(state) do
    Enum.reduce_while(state.windows, {:ok, state}, fn {_window_id, window_payload},
                                                      {:ok, state} ->
      %{op: op, payload: payload} = DisplayProtocol.open_window(window_payload)

      case safe_call(state.client, state.session_id, op, payload) do
        {:ok, _reply} -> {:cont, {:ok, state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp call_with_reconnect(state, op, payload) do
    case safe_call(state.client, state.session_id, op, payload) do
      {:ok, reply} -> {:ok, reply, state}
      {:error, reason} -> maybe_reconnect(reason, state, op, payload)
    end
  end

  defp maybe_reconnect(reason, state, op, payload) do
    if reconnectable?(reason) do
      reconnect_and_retry(state, op, payload)
    else
      {:error, reason, state}
    end
  end

  defp reconnect_and_retry(state, op, payload) do
    case reconnect(state) do
      {:ok, state} -> retry_after_reconnect(state, op, payload)
      {:error, reconnect_reason, state} -> {:error, reconnect_reason, state}
    end
  end

  defp retry_after_reconnect(state, op, payload) do
    case safe_call(state.client, state.session_id, op, payload) do
      {:ok, reply} -> {:ok, reply, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp reconnect(state) do
    stop_client(state.client)

    case connect(%{state | client: nil}) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp safe_call(client, session_id, op, payload) do
    SafeRPC.call(client, op, payload, meta: %{session_id: session_id})
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

  defp put_window(state, %{id: window_id} = window_payload) do
    put_in(state.windows[window_id], window_payload)
  end

  defp put_window(state, _window_payload), do: state

  defp put_resource_state(state, resource_id, resource),
    do: put_in(state.resources[resource_id], resource)

  defp drop_resource_state(state, resource_id),
    do: update_in(state.resources, &Map.delete(&1, resource_id))

  defp put_window_tree(state, window_id, tree) do
    update_in(state.windows, fn windows ->
      Map.update(windows, window_id, %{id: window_id, root: %{tree: tree}}, fn window ->
        root = Map.get(window, :root) || %{}
        Map.put(window, :root, Map.put(root, :tree, tree))
      end)
    end)
  end

  defp new_session_id do
    System.unique_integer([:positive, :monotonic])
  end

  defp normalize_test_event(%{type: _type} = event), do: event

  defp normalize_test_event(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  defp normalize_test_event(event), do: event
end
