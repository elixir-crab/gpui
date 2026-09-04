defmodule GPUITest.Desktop do
  @moduledoc false

  use GenServer

  import ExUnit.Assertions

  alias GPUITest.Desktop.Window

  @update_timeout 3_000

  defstruct [:pid, :ref]

  @type t :: %__MODULE__{pid: pid(), ref: reference()}

  def child_spec(opts) do
    %{
      id: {__MODULE__, make_ref()},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def setup(_context, opts) do
    child_spec =
      Supervisor.child_spec({__MODULE__, Keyword.put(opts, :owner, self())}, id: make_ref())

    pid = ExUnit.Callbacks.start_supervised!(child_spec)
    {:ok, desktop: GenServer.call(pid, :handle)}
  end

  def start_runtime!(%__MODULE__{} = desktop, opts) do
    {app, opts} = Keyword.pop!(opts, :app)
    start_runtime!(desktop, app, opts)
  end

  def start_runtime!(%__MODULE__{} = desktop, app, opts) do
    runtime_opts =
      opts |> Keyword.put(:app, app) |> Keyword.put_new(:display, GPUI.Display.Native)

    child_spec = Supervisor.child_spec({GPUI.Runtime, runtime_opts}, id: make_ref())
    runtime = ExUnit.Callbacks.start_supervised!(child_spec)
    :ok = call(desktop, {:attach, runtime})
    runtime
  end

  @doc false
  def start_native_display! do
    child_spec = Supervisor.child_spec({GPUI.Display.Native, []}, id: make_ref())
    ExUnit.Callbacks.start_supervised!(child_spec)
  end

  @doc false
  @spec stop_process(pid()) :: :ok
  def stop_process(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
    :ok
  catch
    :exit, _reason -> :ok
  end

  def attach(%__MODULE__{} = desktop, source) when is_pid(source),
    do: call(desktop, {:attach, source})

  def platform(%__MODULE__{} = desktop), do: call(desktop, :platform)
  def capabilities(%__MODULE__{} = desktop), do: call(desktop, :capabilities)

  def require_capability!(%__MODULE__{} = desktop, capability) do
    unless MapSet.member?(capabilities(desktop), capability),
      do: flunk("desktop backend #{platform(desktop)} lacks #{inspect(capability)}")

    :ok
  end

  def window!(%__MODULE__{} = desktop, title) when is_binary(title),
    do: call(desktop, {:window, title})

  def window_info!(%__MODULE__{} = desktop, %Window{} = window),
    do: call(desktop, {:window_info, window})

  def request_frame!(%__MODULE__{} = desktop, %Window{} = window),
    do: call(desktop, {:request_frame, window})

  def move!(%__MODULE__{} = desktop, %Window{} = window, opts),
    do: call(desktop, {:move, window, point!(opts)})

  def click!(%__MODULE__{} = desktop, %Window{} = window, opts),
    do: call(desktop, {:click, window, point!(opts)})

  def scroll!(%__MODULE__{} = desktop, %Window{} = window, opts) do
    {x, y} = point!(opts)
    {delta_x, delta_y} = Keyword.fetch!(opts, :delta)
    call(desktop, {:scroll, window, {x, y}, {delta_x, delta_y}})
  end

  def type!(%__MODULE__{} = desktop, %Window{} = window, text),
    do: call(desktop, {:type, window, text})

  def press!(%__MODULE__{} = desktop, %Window{} = window, key),
    do: call(desktop, {:press, window, key})

  def close_window!(%__MODULE__{} = desktop, %Window{} = window),
    do: call(desktop, {:close_window, window})

  def capture!(%__MODULE__{} = desktop, %Window{} = window, path),
    do: call(desktop, {:capture, window, path})

  def capture_fixture!(%__MODULE__{} = desktop, %Window{} = window, name) do
    case System.get_env("GPUI_E2E_CAPTURE_DIR") do
      nil ->
        :ok

      directory ->
        File.mkdir_p!(directory)
        capture!(desktop, window, Path.join(directory, name <> ".png"))
    end
  end

  def repeat_click!(%__MODULE__{} = desktop, %Window{} = window, opts) do
    {x, y} = point!(opts)
    count = Keyword.fetch!(opts, :count)
    call(desktop, {:repeat_click, window, {x, y}, count})
  end

  def drag!(%__MODULE__{} = desktop, %Window{} = window, opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    call(desktop, {:drag, window, from, to})
  end

  def resize!(%__MODULE__{} = desktop, %Window{} = window, opts) do
    {width, height} = Keyword.fetch!(opts, :to)
    call(desktop, {:resize, window, {width, height}})
  end

  def await_frame!(%__MODULE__{} = desktop, source, window_id, %Window{} = window) do
    if runtime_process?(source), do: :ok = GPUI.Runtime.request_frame(source)
    request_frame!(desktop, window)
    assert :ok = GPUI.Display.Support.call_await_frame(source, window_id, @update_timeout)
  end

  def await_frame_after!(runtime, window_id, generation, timeout \\ @update_timeout) do
    assert :ok =
             GPUI.Display.Support.call_await_frame_after(runtime, window_id, generation, timeout)
  end

  def assert_no_runtime_update!(desktop, runtime, window_id, window, action) do
    flush_updates(runtime)
    assert {:ok, generation} = GPUI.Runtime.frame_token(runtime, window_id)
    action.()
    assert :ok = GPUI.Runtime.request_frame(runtime)
    request_frame!(desktop, window)
    await_frame_after!(runtime, window_id, generation)
    GPUI.Runtime.drain_events(runtime)
    refute_receive {:gpui, ^runtime, %GPUI.Runtime.Update{}}, 0
  end

  def eventually(%__MODULE__{} = desktop, runtime, fun, timeout \\ @update_timeout) do
    ensure_attached!(desktop, runtime)
    deadline = System.monotonic_time(:millisecond) + timeout
    await_update(runtime, fun, deadline, nil)
  end

  @impl GenServer
  def init(opts) do
    owner = Keyword.fetch!(opts, :owner)
    backend = backend()
    owner_monitor = Process.monitor(owner)

    {:ok,
     %{
       backend: backend,
       owner: owner,
       owner_monitor: owner_monitor,
       ref: make_ref(),
       runtimes: %{},
       windows: %{}
     }}
  end

  @impl GenServer
  def handle_call(:handle, _from, state), do: {:reply, handle(state), state}

  def handle_call({:command, ref, command}, _from, %{ref: ref} = state),
    do: command(command, state)

  @impl GenServer
  def handle_info({:gpui, runtime, %GPUI.Runtime.Update{} = update}, state) do
    if Map.has_key?(state.runtimes, runtime), do: send(state.owner, {:gpui, runtime, update})
    {:noreply, state}
  end

  def handle_info(
        {:DOWN, monitor, :process, owner, _reason},
        %{owner: owner, owner_monitor: monitor} = state
      ),
      do: {:stop, :normal, state}

  def handle_info({:DOWN, monitor, :process, runtime, _reason}, state) do
    case Map.get(state.runtimes, runtime) do
      ^monitor -> {:noreply, %{state | runtimes: Map.delete(state.runtimes, runtime)}}
      _other -> {:noreply, state}
    end
  end

  defp command({:attach, runtime}, state) do
    case Map.fetch(state.runtimes, runtime) do
      {:ok, _monitor} ->
        {:reply, :ok, state}

      :error ->
        monitor = Process.monitor(runtime)
        :ok = subscribe(runtime)
        {:reply, :ok, %{state | runtimes: Map.put(state.runtimes, runtime, monitor)}}
    end
  end

  defp command({:attached?, runtime}, state),
    do: {:reply, Map.has_key?(state.runtimes, runtime), state}

  defp command(:platform, state), do: {:reply, platform_for(state.backend), state}
  defp command(:capabilities, state), do: {:reply, state.backend.capabilities(), state}

  defp command({:window, title}, state) do
    id = state.backend.window_id!(title)
    window = %Window{desktop_ref: state.ref, id: id, title: title}
    {:reply, window, %{state | windows: Map.put(state.windows, id, window)}}
  end

  defp command({:window_info, window}, state), do: backend_reply(state, window, :window_info!, [])

  defp command({:request_frame, window}, state),
    do: backend_reply(state, window, :request_frame!, [1, 1])

  defp command({:move, window, {x, y}}, state),
    do: backend_reply(state, window, :request_frame!, [x, y])

  defp command({:click, window, {x, y}}, state), do: backend_reply(state, window, :click!, [x, y])

  defp command({:scroll, window, {x, y}, {dx, dy}}, state),
    do: backend_reply(state, window, :scroll!, [x, y, dx, dy])

  defp command({:type, window, text}, state), do: backend_reply(state, window, :type!, [text])
  defp command({:press, window, key}, state), do: backend_reply(state, window, :key!, [key])

  defp command({:close_window, window}, state),
    do: backend_reply(state, window, :close_window!, [])

  defp command({:capture, window, path}, state),
    do: backend_reply(state, window, :capture!, [path])

  defp command({:repeat_click, window, {x, y}, count}, state),
    do: backend_reply(state, window, :repeat_click!, [x, y, count])

  defp command({:drag, window, {from_x, from_y}, {to_x, to_y}}, state),
    do: backend_reply(state, window, :drag!, [from_x, from_y, to_x, to_y])

  defp command({:resize, window, {width, height}}, state),
    do: backend_reply(state, window, :resize!, [width, height])

  defp backend_reply(state, %Window{desktop_ref: ref, id: id}, function, args)
       when ref == state.ref do
    {:reply, apply(state.backend, function, [id | args]), state}
  end

  defp call(%__MODULE__{} = desktop, command),
    do: GenServer.call(desktop.pid, {:command, desktop.ref, command}, 10_000)

  defp ensure_attached!(desktop, runtime) do
    if runtime_attached?(desktop, runtime),
      do: :ok,
      else: raise(ArgumentError, "runtime is not owned by this desktop session")
  end

  defp runtime_attached?(desktop, runtime), do: call(desktop, {:attached?, runtime})

  defp await_update(runtime, fun, deadline, last_error) do
    case evaluate(fun) do
      {:ok, value} when value not in [false, nil] ->
        value

      result ->
        last_error = if match?({:error, _}, result), do: elem(result, 1), else: last_error
        remaining = max(deadline - System.monotonic_time(:millisecond), 0)

        receive do
          {:gpui, ^runtime, %GPUI.Runtime.Update{}} ->
            await_update(runtime, fun, deadline, last_error)
        after
          remaining ->
            flunk("runtime did not reach the expected state; last error: #{inspect(last_error)}")
        end
    end
  end

  defp evaluate(fun) do
    {:ok, fun.()}
  rescue
    error in [ExUnit.AssertionError, MatchError] -> {:error, error}
  catch
    :exit, reason -> {:error, reason}
  end

  defp flush_updates(source) do
    receive do
      {:gpui, ^source, %GPUI.Runtime.Update{}} -> flush_updates(source)
    after
      0 -> :ok
    end
  end

  defp point!(opts), do: Keyword.fetch!(opts, :at)
  defp handle(state), do: %__MODULE__{pid: self(), ref: state.ref}

  defp subscribe(source) do
    cond do
      function_exported?(GPUI.Runtime, :subscribe, 1) and runtime_process?(source) ->
        GPUI.Runtime.subscribe(source)

      function_exported?(GPUI.Remote.Client, :subscribe, 1) ->
        GPUI.Remote.Client.subscribe(source)
    end
  end

  defp runtime_process?(source) do
    case Process.info(source, :dictionary) do
      {:dictionary, dictionary} ->
        Keyword.get(dictionary, :"$initial_call") == {GPUI.Runtime, :init, 1}

      nil ->
        false
    end
  end

  defp backend do
    case :os.type() do
      {:unix, :darwin} -> GPUITest.Desktop.MacOS
      {:unix, _name} -> GPUITest.Desktop.Linux
    end
  end

  defp platform_for(GPUITest.Desktop.MacOS), do: :macos
  defp platform_for(GPUITest.Desktop.Linux), do: :linux
end
