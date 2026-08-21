defmodule GPUI.Test.Native do
  @moduledoc false

  use GenServer

  alias GPUI.Native.Test, as: NativeTest
  alias GPUI.Test.{Error, UI}

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
  def bounds(%UI{} = ui, target), do: call(ui, {:bounds, target})

  @spec settle(UI.t()) :: UI.t()
  def settle(%UI{} = ui), do: call(ui, :settle)

  @spec advance(UI.t(), non_neg_integer()) :: UI.t()
  def advance(%UI{} = ui, milliseconds), do: call(ui, {:advance, milliseconds})

  @impl GenServer
  def init(opts) do
    owner = Keyword.fetch!(opts, :owner)
    {width, height} = Keyword.get(opts, :size, {640, 480})
    id = native!(nil, :start, {width, height}, NativeTest.start(width, height))
    ref = make_ref()
    Process.monitor(owner)
    {:ok, %{id: id, owner: owner, ref: ref}}
  end

  @impl GenServer
  def handle_call(:ui, _from, state), do: {:reply, handle(state), state}

  def handle_call({:render, ref, view, assigns}, _from, %{ref: ref} = state) do
    tree = view |> GPUI.Test.render(assigns) |> GPUI.Element.to_payload()
    reply(state, :render, view, NativeTest.render(state.id, viewport(tree)))
  end

  def handle_call({:focus, ref, target}, _from, %{ref: ref} = state),
    do: reply(state, :focus, target, NativeTest.focus(state.id, target))

  def handle_call({:press, ref, key}, _from, %{ref: ref} = state),
    do: reply(state, :press, key, NativeTest.press(state.id, keystroke(key)))

  def handle_call({:click, ref, {x, y}}, _from, %{ref: ref} = state)
      when is_number(x) and is_number(y),
      do: reply(state, :click, {x, y}, NativeTest.click_at(state.id, x, y))

  def handle_call({:click, ref, target}, _from, %{ref: ref} = state),
    do: reply(state, :click, target, NativeTest.click(state.id, target))

  def handle_call({:scroll, ref, target, opts}, _from, %{ref: ref} = state) do
    {delta_x, delta_y} = Keyword.fetch!(opts, :delta)

    if not (is_number(delta_x) and is_number(delta_y) and
              abs(delta_x) <= 100_000 and abs(delta_y) <= 100_000) do
      raise ArgumentError,
            "expected bounded numeric scroll delta, got: #{inspect({delta_x, delta_y})}"
    end

    reply(
      state,
      :scroll,
      {target, {delta_x, delta_y}},
      NativeTest.scroll(state.id, target, delta_x, delta_y)
    )
  end

  def handle_call({:type, ref, text}, _from, %{ref: ref} = state),
    do: reply(state, :type, text, NativeTest.input(state.id, text))

  def handle_call({:resize, ref, {width, height}}, _from, %{ref: ref} = state)
      when is_number(width) and is_number(height) and width > 0 and height > 0,
      do: reply(state, :resize, {width, height}, NativeTest.resize(state.id, width, height))

  def handle_call({:bounds, ref, target}, _from, %{ref: ref} = state) do
    case native_result(state, :bounds, target, NativeTest.bounds(state.id, target)) do
      {:ok, {x, y, width, height}} ->
        {:reply, %{x: x, y: y, width: width, height: height}, state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:settle, ref}, _from, %{ref: ref} = state),
    do: reply(state, :settle, nil, NativeTest.settle(state.id))

  def handle_call({:advance, ref, milliseconds}, _from, %{ref: ref} = state)
      when is_integer(milliseconds) and milliseconds >= 0,
      do: reply(state, :advance, milliseconds, NativeTest.advance(state.id, milliseconds))

  @impl GenServer
  def handle_info({:DOWN, _monitor, :process, owner, _reason}, %{owner: owner} = state),
    do: {:stop, :normal, state}

  @impl GenServer
  def terminate(_reason, state) do
    _ = native!(state, :stop, nil, NativeTest.stop(state.id))
    :ok
  end

  defp call(%UI{} = ui, command) do
    case GenServer.call(ui.pid, Tuple.insert_at(command_tuple(command), 1, ui.ref)) do
      {:error, %Error{} = error} -> raise error
      value -> value
    end
  end

  defp reply(state, operation, subject, result) do
    case native_result(state, operation, subject, result) do
      {:ok, _value} -> {:reply, handle(state), deliver_events(state)}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  defp command_tuple(command) when is_tuple(command), do: command
  defp command_tuple(command), do: {command}

  defp deliver_events(state) do
    events = native!(state, :events, nil, NativeTest.events(state.id))
    ui = handle(state)
    Enum.each(events, &send(state.owner, {:gpui, ui, {:event, &1}}))
    state
  end

  defp native!(_state, _operation, _subject, {:ok, :ok}), do: :ok
  defp native!(_state, _operation, _subject, {:ok, value}), do: value

  defp native!(_state, _operation, _subject, {:ok, x, y, width, height}),
    do: {x, y, width, height}

  defp native!(state, operation, subject, {:error, reason}) do
    raise error(state, operation, subject, reason)
  end

  defp native_result(_state, _operation, _subject, {:ok, :ok}), do: {:ok, :ok}
  defp native_result(_state, _operation, _subject, {:ok, value}), do: {:ok, value}

  defp native_result(_state, _operation, _subject, {:ok, x, y, width, height}),
    do: {:ok, {x, y, width, height}}

  defp native_result(state, operation, subject, {:error, reason}),
    do: {:error, error(state, operation, subject, reason)}

  defp error(state, operation, subject, reason) do
    Error.exception(
      operation: operation,
      subject: subject,
      reason: reason,
      ui: state && handle(state)
    )
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
