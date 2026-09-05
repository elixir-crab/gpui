defmodule GPUI.Test.NativeSession do
  @moduledoc """
  Supervised adapter for deterministic native UI operations.

  `GPUI.Test` owns the supported testing workflow. This process module is
  documented for maintainers and excluded from the package's public API
  reference.
  """

  use GenServer

  alias GPUI.Native.TestDriver, as: NativeTest
  alias GPUI.Test.{NativeError, UI}

  @max_target_bytes 1_024
  @max_input_bytes 1_048_576
  @max_viewport_axis 32_768
  @max_coordinate 1_000_000
  @max_scroll_delta 100_000
  @max_advance_ms 86_400_000
  @max_key_bytes 256

  @semantic_keys ~w(arrow_left arrow_right arrow_up arrow_down space enter escape tab)a

  def stop(%UI{} = ui) do
    if Process.alive?(ui.pid), do: GenServer.stop(ui.pid, :normal)
    :ok
  catch
    :exit, _reason -> :ok
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @spec ui(pid()) :: UI.t()
  def ui(pid) when is_pid(pid), do: GenServer.call(pid, :ui)

  @spec render(UI.t(), module(), map() | keyword()) :: UI.t()
  def render(%UI{} = ui, view, assigns), do: call(ui, {:render, view, assigns})

  @spec focus(UI.t(), String.t()) :: UI.t()
  def focus(%UI{} = ui, target), do: call(ui, {:focus, target!(target)})

  @spec press(UI.t(), atom() | String.t()) :: UI.t()
  def press(%UI{} = ui, key), do: call(ui, {:press, key!(key)})

  @spec click(UI.t(), String.t() | {number(), number()}) :: UI.t()
  def click(%UI{} = ui, {x, y}), do: call(ui, {:click, point!({x, y})})
  def click(%UI{} = ui, target), do: call(ui, {:click, target!(target)})

  @spec scroll(UI.t(), String.t(), keyword()) :: UI.t()
  def scroll(%UI{} = ui, target, opts),
    do: call(ui, {:scroll, target!(target), scroll_opts!(opts)})

  @spec type(UI.t(), String.t()) :: UI.t()
  def type(%UI{} = ui, text), do: call(ui, {:type, text!(text)})

  @spec resize(UI.t(), {number(), number()}) :: UI.t()
  def resize(%UI{} = ui, size), do: call(ui, {:resize, size!(size)})

  @spec bounds(UI.t(), String.t()) :: map()
  def bounds(%UI{} = ui, target), do: call(ui, {:bounds, target!(target)})

  @spec settle(UI.t()) :: UI.t()
  def settle(%UI{} = ui), do: call(ui, :settle)

  @spec advance(UI.t(), non_neg_integer()) :: UI.t()
  def advance(%UI{} = ui, milliseconds), do: call(ui, {:advance, advance!(milliseconds)})

  @impl GenServer
  def init(opts) do
    owner = Keyword.fetch!(opts, :owner)
    {width, height} = opts |> Keyword.get(:size, {640, 480}) |> size!()
    session = native!(nil, :start, {width, height}, NativeTest.start(width, height))
    ref = make_ref()
    Process.monitor(owner)
    {:ok, %{session: session, owner: owner, ref: ref}}
  end

  @impl GenServer
  def handle_call(:ui, _from, state), do: {:reply, handle(state), state}

  def handle_call({:render, ref, view, assigns}, _from, %{ref: ref} = state) do
    tree = view |> GPUI.Test.render(assigns) |> GPUI.Element.to_payload()
    reply(state, :render, view, NativeTest.render(state.session, viewport(tree)))
  end

  def handle_call({:focus, ref, target}, _from, %{ref: ref} = state),
    do: reply(state, :focus, target, NativeTest.focus(state.session, target))

  def handle_call({:press, ref, key}, _from, %{ref: ref} = state),
    do: reply(state, :press, key, NativeTest.press(state.session, keystroke(key)))

  def handle_call({:click, ref, {x, y}}, _from, %{ref: ref} = state)
      when is_number(x) and is_number(y),
      do: reply(state, :click, {x, y}, NativeTest.click_at(state.session, x, y))

  def handle_call({:click, ref, target}, _from, %{ref: ref} = state),
    do: reply(state, :click, target, NativeTest.click(state.session, target))

  def handle_call({:scroll, ref, target, opts}, _from, %{ref: ref} = state) do
    {delta_x, delta_y} = Keyword.fetch!(opts, :delta)

    reply(
      state,
      :scroll,
      {target, {delta_x, delta_y}},
      NativeTest.scroll(state.session, target, delta_x, delta_y)
    )
  end

  def handle_call({:type, ref, text}, _from, %{ref: ref} = state),
    do: reply(state, :type, text, NativeTest.input(state.session, text))

  def handle_call({:resize, ref, {width, height}}, _from, %{ref: ref} = state)
      when is_number(width) and is_number(height) and width > 0 and height > 0,
      do: reply(state, :resize, {width, height}, NativeTest.resize(state.session, width, height))

  def handle_call({:bounds, ref, target}, _from, %{ref: ref} = state) do
    case native_result(state, :bounds, target, NativeTest.bounds(state.session, target)) do
      {:ok, {x, y, width, height}} ->
        {:reply, %{x: x, y: y, width: width, height: height}, state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:settle, ref}, _from, %{ref: ref} = state),
    do: reply(state, :settle, nil, NativeTest.settle(state.session))

  def handle_call({:advance, ref, milliseconds}, _from, %{ref: ref} = state)
      when is_integer(milliseconds) and milliseconds >= 0,
      do: reply(state, :advance, milliseconds, NativeTest.advance(state.session, milliseconds))

  @impl GenServer
  def handle_info({:DOWN, _monitor, :process, owner, _reason}, %{owner: owner} = state),
    do: {:stop, :normal, state}

  @impl GenServer
  def terminate(_reason, state) do
    _ = native!(state, :stop, nil, NativeTest.stop(state.session))
    :ok
  end

  defp call(%UI{} = ui, command) do
    case GenServer.call(ui.pid, Tuple.insert_at(command_tuple(command), 1, ui.ref)) do
      {:error, %NativeError{} = error} -> raise error
      value -> value
    end
  catch
    :exit, reason ->
      raise NativeError,
        operation: :session,
        subject: command,
        reason: session_reason(reason),
        ui: ui
  end

  defp session_reason({:noproc, _call}), do: :session_stopped
  defp session_reason({:normal, _call}), do: :session_stopped
  defp session_reason(reason), do: reason

  defp reply(state, operation, subject, result) do
    case native_result(state, operation, subject, result) do
      {:ok, _value} -> {:reply, handle(state), deliver_events(state)}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  defp command_tuple(command) when is_tuple(command), do: command
  defp command_tuple(command), do: {command}

  defp deliver_events(state) do
    events = native!(state, :events, nil, NativeTest.events(state.session))
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
    NativeError.exception(
      operation: operation,
      subject: subject,
      reason: reason,
      ui: state && handle(state)
    )
  end

  defp finite_number?(value) when is_integer(value), do: true
  defp finite_number?(value) when is_float(value), do: true
  defp finite_number?(_value), do: false

  defp size!({width, height} = size) do
    if finite_number?(width) and finite_number?(height) and width > 0 and height > 0 and
         width <= @max_viewport_axis and height <= @max_viewport_axis do
      size
    else
      raise ArgumentError,
            "expected UI size axes in 1..#{@max_viewport_axis}, got: #{inspect(size)}"
    end
  end

  defp target!(target) when is_binary(target) do
    if target != "" and byte_size(target) <= @max_target_bytes and String.valid?(target) do
      target
    else
      raise ArgumentError,
            "expected non-empty UTF-8 target up to #{@max_target_bytes} bytes, got: #{inspect(target)}"
    end
  end

  defp target!(target),
    do: raise(ArgumentError, "expected target ID to be a string, got: #{inspect(target)}")

  defp point!({x, y} = point) do
    if finite_number?(x) and finite_number?(y) and abs(x) <= @max_coordinate and
         abs(y) <= @max_coordinate do
      point
    else
      raise ArgumentError,
            "expected coordinates within ±#{@max_coordinate}, got: #{inspect(point)}"
    end
  end

  defp scroll_opts!(opts) when is_list(opts) do
    case opts do
      [delta: {x, y} = delta] -> valid_scroll_delta!(delta, x, y, opts)
      _other -> invalid_scroll!(opts)
    end
  end

  defp scroll_opts!(opts), do: invalid_scroll!(opts)

  defp valid_scroll_delta!(delta, x, y, opts) do
    if finite_number?(x) and finite_number?(y) and abs(x) <= @max_scroll_delta and
         abs(y) <= @max_scroll_delta,
       do: [delta: delta],
       else: invalid_scroll!(opts)
  end

  defp invalid_scroll!(opts),
    do:
      raise(
        ArgumentError,
        "expected only delta: {x, y} within ±#{@max_scroll_delta}, got: #{inspect(opts)}"
      )

  defp text!(text) when is_binary(text) and byte_size(text) <= @max_input_bytes, do: text

  defp text!(text),
    do:
      raise(
        ArgumentError,
        "expected input text up to #{@max_input_bytes} bytes, got: #{inspect(text)}"
      )

  defp advance!(milliseconds)
       when is_integer(milliseconds) and milliseconds >= 0 and milliseconds <= @max_advance_ms,
       do: milliseconds

  defp advance!(milliseconds),
    do:
      raise(
        ArgumentError,
        "expected advance milliseconds in 0..#{@max_advance_ms}, got: #{inspect(milliseconds)}"
      )

  defp key!(key) when key in @semantic_keys, do: key

  defp key!(key) when is_binary(key) do
    if key != "" and byte_size(key) <= @max_key_bytes and String.valid?(key),
      do: key,
      else:
        raise(
          ArgumentError,
          "expected non-empty UTF-8 key up to #{@max_key_bytes} bytes, got: #{inspect(key)}"
        )
  end

  defp key!(key),
    do:
      raise(
        ArgumentError,
        "expected a documented semantic key or raw key string, got: #{inspect(key)}"
      )

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
