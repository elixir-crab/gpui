defmodule GPUI.Backend.RemoteLoopback.Server do
  @moduledoc false

  use GenServer

  alias GPUI.Remote.DisplayProtocol

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec request(GenServer.server(), DisplayProtocol.message()) :: term()
  def request(server, message) do
    message = message |> :erlang.term_to_binary() |> :erlang.binary_to_term([:safe])
    GenServer.call(server, {:runtime_message, message})
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{windows: %{}, events: []}}
  end

  @impl GenServer
  def handle_call({:runtime_message, %{op: :open_window, payload: window}}, _from, state) do
    {:reply, :ok, put_window(state, window)}
  end

  def handle_call(
        {:runtime_message, %{op: :update_window, payload: %{window_id: window_id, tree: tree}}},
        _from,
        state
      ) do
    state =
      state
      |> update_window_tree(window_id, tree)
      |> push_event(%{type: :window_updated, window_id: window_id})

    {:reply, :ok, state}
  end

  def handle_call({:runtime_message, %{op: :event, payload: event}}, _from, state) do
    {:reply, {:ok, :ok}, push_event(state, event)}
  end

  def handle_call({:runtime_message, %{op: :drain_events}}, _from, state) do
    {:reply, {:ok, Enum.reverse(state.events)}, %{state | events: []}}
  end

  defp put_window(state, %{id: id} = window) when is_integer(id) do
    put_in(state, [:windows, id], window)
  end

  defp update_window_tree(state, window_id, tree) do
    update_in(state.windows, fn windows ->
      Map.update(windows, window_id, %{id: window_id, root: %{tree: tree}}, fn window ->
        put_in(window, [:root, :tree], tree)
      end)
    end)
  end

  defp push_event(state, event), do: update_in(state.events, &[event | &1])
end
