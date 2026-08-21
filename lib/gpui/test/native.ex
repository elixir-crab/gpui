defmodule GPUI.Test.Native do
  @moduledoc false

  use GenServer

  alias GPUI.Native.Test, as: NativeTest
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

  @spec click(UI.t(), String.t() | {number(), number()}) :: UI.t()
  def click(%UI{} = ui, target), do: call(ui, {:click, target})

  @spec scroll(UI.t(), String.t(), keyword()) :: UI.t()
  def scroll(%UI{} = ui, target, opts), do: call(ui, {:scroll, target, opts})

  @spec type(UI.t(), String.t()) :: UI.t()
  def type(%UI{} = ui, text), do: call(ui, {:type, text})

  @spec resize(UI.t(), {number(), number()}) :: UI.t()
  def resize(%UI{} = ui, size), do: call(ui, {:resize, size})

  @spec bounds(UI.t(), String.t()) :: map()
  def bounds(%UI{} = ui, target), do: GenServer.call(ui.pid, {:bounds, ui.ref, target})

  @spec settle(UI.t()) :: UI.t()
  def settle(%UI{} = ui), do: call(ui, :settle)

  @spec advance(UI.t(), non_neg_integer()) :: UI.t()
  def advance(%UI{} = ui, milliseconds), do: call(ui, {:advance, milliseconds})

  @impl GenServer
  def init(opts) do
    owner = Keyword.fetch!(opts, :owner)
    {width, height} = Keyword.get(opts, :size, {640, 480})
    {:ok, id} = NativeTest.start(width, height)
    ref = make_ref()
    Process.monitor(owner)
    {:ok, %{id: id, owner: owner, ref: ref}}
  end

  @impl GenServer
  def handle_call(:ui, _from, state), do: {:reply, handle(state), state}

  def handle_call({:render, ref, view, assigns}, _from, %{ref: ref} = state) do
    tree = view |> GPUI.Test.render(assigns) |> GPUI.Element.to_payload()
    {:ok, :ok} = NativeTest.render(state.id, viewport(tree))
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:focus, ref, target}, _from, %{ref: ref} = state) do
    {:ok, :ok} = NativeTest.focus(state.id, target)
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:press, ref, key}, _from, %{ref: ref} = state) do
    {:ok, :ok} = NativeTest.press(state.id, keystroke(key))
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:click, ref, {x, y}}, _from, %{ref: ref} = state)
      when is_number(x) and is_number(y) do
    native!(NativeTest.click_at(state.id, x, y), :click, {x, y})
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:click, ref, target}, _from, %{ref: ref} = state) do
    native!(NativeTest.click(state.id, target), :click, target)
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:scroll, ref, target, opts}, _from, %{ref: ref} = state) do
    {delta_x, delta_y} = Keyword.fetch!(opts, :delta)

    if not (is_number(delta_x) and is_number(delta_y) and
              abs(delta_x) <= 100_000 and abs(delta_y) <= 100_000) do
      raise ArgumentError,
            "expected bounded numeric scroll delta, got: #{inspect({delta_x, delta_y})}"
    end

    native!(
      NativeTest.scroll(state.id, target, delta_x, delta_y),
      :scroll,
      {target, {delta_x, delta_y}}
    )

    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:type, ref, text}, _from, %{ref: ref} = state) do
    native!(NativeTest.input(state.id, text), :type, text)
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:resize, ref, {width, height}}, _from, %{ref: ref} = state)
      when is_number(width) and is_number(height) and width > 0 and height > 0 do
    native!(NativeTest.resize(state.id, width, height), :resize, {width, height})
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:bounds, ref, target}, _from, %{ref: ref} = state) do
    {:ok, x, y, width, height} = NativeTest.bounds(state.id, target)
    {:reply, %{x: x, y: y, width: width, height: height}, state}
  end

  def handle_call({:settle, ref}, _from, %{ref: ref} = state) do
    {:ok, :ok} = NativeTest.settle(state.id)
    {:reply, handle(state), deliver_events(state)}
  end

  def handle_call({:advance, ref, milliseconds}, _from, %{ref: ref} = state)
      when is_integer(milliseconds) and milliseconds >= 0 do
    native!(NativeTest.advance(state.id, milliseconds), :advance, milliseconds)
    {:reply, handle(state), deliver_events(state)}
  end

  @impl GenServer
  def handle_info({:DOWN, _monitor, :process, owner, _reason}, %{owner: owner} = state),
    do: {:stop, :normal, state}

  @impl GenServer
  def terminate(_reason, state) do
    _ = NativeTest.stop(state.id)
    :ok
  end

  defp call(%UI{} = ui, command) do
    GenServer.call(ui.pid, Tuple.insert_at(command_tuple(command), 1, ui.ref))
  end

  defp command_tuple(command) when is_tuple(command), do: command
  defp command_tuple(command), do: {command}

  defp deliver_events(state) do
    {:ok, events} = NativeTest.events(state.id)
    ui = handle(state)
    Enum.each(events, &send(state.owner, {:gpui, ui, {:event, &1}}))
    state
  end

  defp native!({:ok, :ok}, _operation, _subject), do: :ok

  defp native!({:error, reason}, operation, subject) do
    raise "GPUI native test #{operation} failed for #{inspect(subject)}: #{reason}"
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
