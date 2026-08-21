defmodule GPUI.Test.Native do
  @moduledoc false

  use GenServer

  alias GPUI.Test.UI

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @spec ui(pid()) :: UI.t()
  def ui(pid) when is_pid(pid), do: GenServer.call(pid, :ui)

  @spec render(UI.t(), module(), map() | keyword()) :: UI.t()
  def render(%UI{} = ui, view, assigns), do: call(ui, {:render, view, assigns})

  @spec focus(UI.t(), String.t()) :: UI.t()
  def focus(%UI{} = ui, target), do: call(ui, {:focus, target})

  @spec press(UI.t(), atom() | String.t()) :: UI.t()
  def press(%UI{} = ui, key), do: call(ui, {:press, key})

  @spec click(UI.t(), String.t()) :: UI.t()
  def click(%UI{} = ui, target), do: call(ui, {:click, target})

  @spec bounds(UI.t(), String.t()) :: map()
  def bounds(%UI{} = ui, target), do: GenServer.call(ui.pid, {:bounds, ui.ref, target})

  @spec settle(UI.t()) :: UI.t()
  def settle(%UI{} = ui), do: call(ui, :settle)

  @impl GenServer
  def init(opts) do
    owner = Keyword.fetch!(opts, :owner)
    {width, height} = Keyword.get(opts, :size, {640, 480})
    {:ok, id} = GPUI.Native.native_test_start(width, height)
    ref = make_ref()
    Process.monitor(owner)
    {:ok, %{id: id, owner: owner, ref: ref}}
  end

  @impl GenServer
  def handle_call(:ui, _from, state), do: {:reply, handle(state), state}

  def handle_call({:render, ref, view, assigns}, _from, %{ref: ref} = state) do
    tree = view |> GPUI.Test.render(assigns) |> GPUI.Element.to_payload()
    {:ok, :ok} = GPUI.Native.native_test_render(state.id, viewport(tree))
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:focus, ref, target}, _from, %{ref: ref} = state) do
    {:ok, :ok} = GPUI.Native.native_test_focus(state.id, target)
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:press, ref, key}, _from, %{ref: ref} = state) do
    {:ok, :ok} = GPUI.Native.native_test_key(state.id, keystroke(key))
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:click, ref, target}, _from, %{ref: ref} = state) do
    {:ok, :ok} = GPUI.Native.native_test_click(state.id, target)
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:bounds, ref, target}, _from, %{ref: ref} = state) do
    {:ok, x, y, width, height} = GPUI.Native.native_test_bounds(state.id, target)
    {:reply, %{x: x, y: y, width: width, height: height}, state}
  end

  def handle_call({:settle, ref}, _from, %{ref: ref} = state) do
    {:ok, :ok} = GPUI.Native.native_test_idle(state.id)
    {:reply, handle(state), deliver_events(state)}
  end

  @impl GenServer
  def handle_info({:DOWN, _monitor, :process, owner, _reason}, %{owner: owner} = state),
    do: {:stop, :normal, state}

  @impl GenServer
  def terminate(_reason, state) do
    _ = GPUI.Native.native_test_stop(state.id)
    :ok
  end

  defp call(%UI{} = ui, command) do
    GenServer.call(ui.pid, Tuple.insert_at(command_tuple(command), 1, ui.ref))
  end

  defp command_tuple(command) when is_tuple(command), do: command
  defp command_tuple(command), do: {command}

  defp deliver_events(state) do
    {:ok, events} = GPUI.Native.native_test_events(state.id)
    ui = handle(state)
    Enum.each(events, &send(state.owner, {:gpui, ui, {:event, &1}}))
    state
  end

  defp viewport(tree), do: Map.new(type: :viewport, attrs: %{}, children: [tree])
  defp handle(state), do: %UI{pid: self(), ref: state.ref}

  defp keystroke(:arrow_left), do: "left"
  defp keystroke(:arrow_right), do: "right"
  defp keystroke(:arrow_up), do: "up"
  defp keystroke(:arrow_down), do: "down"
  defp keystroke(:space), do: "space"
  defp keystroke(:enter), do: "enter"
  defp keystroke(:escape), do: "escape"
  defp keystroke(:tab), do: "tab"
  defp keystroke(key) when is_binary(key), do: key
end
