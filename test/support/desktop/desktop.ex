defmodule GPUITest.Desktop do
  @moduledoc false

  import ExUnit.Assertions

  @update_timeout 3_000
  @backend (case :os.type() do
              {:unix, :darwin} -> GPUITest.Desktop.MacOS
              {:unix, _name} -> GPUITest.Desktop.Linux
            end)

  def platform, do: if(@backend == GPUITest.Desktop.MacOS, do: :macos, else: :linux)
  def capabilities, do: @backend.capabilities()
  def window_id!(title), do: @backend.window_id!(title)
  def request_frame!(window_id, x \\ 1, y \\ 1), do: @backend.request_frame!(window_id, x, y)
  def click!(window_id, x, y), do: @backend.click!(window_id, x, y)
  def type!(window_id, text), do: @backend.type!(window_id, text)
  def key!(window_id, key), do: @backend.key!(window_id, key)
  def close_window!(window_id), do: @backend.close_window!(window_id)
  def capture!(window_id, path), do: @backend.capture!(window_id, path)
  def repeat_click!(window_id, x, y, count), do: @backend.repeat_click!(window_id, x, y, count)

  def window_info!(window_id) do
    @backend.window_info!(window_id)
  end

  def drag!(window_id, from_x, from_y, to_x, to_y),
    do: @backend.drag!(window_id, from_x, from_y, to_x, to_y)

  def resize!(window_id, width, height), do: @backend.resize!(window_id, width, height)

  def require_capability!(capability) do
    unless MapSet.member?(capabilities(), capability),
      do: flunk("desktop backend #{platform()} lacks #{inspect(capability)}")

    :ok
  end

  def await_frame!(source, window_id, native_window_id) do
    nudge_frame!(native_window_id)
    assert :ok = GPUI.Display.call_await_frame(source, window_id, @update_timeout)
  end

  def await_frame_after!(source, window_id, generation, timeout \\ @update_timeout) do
    assert :ok = GPUI.Display.call_await_frame_after(source, window_id, generation, timeout)
  end

  def assert_no_runtime_update!(runtime, window_id, native_window_id, action) do
    flush_updates(runtime)
    assert {:ok, generation} = GPUI.Runtime.frame_token(runtime, window_id)
    action.()
    assert :ok = GPUI.Runtime.request_frame(runtime)
    nudge_frame!(native_window_id)
    await_frame_after!(runtime, window_id, generation)
    GPUI.Runtime.drain_events(runtime)
    refute_receive {:gpui, ^runtime, %GPUI.Runtime.Update{}}, 0
  end

  def eventually(fun, timeout \\ @update_timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    await_update(fun, deadline, nil)
  end

  def stop_process(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp await_update(fun, deadline, last_error) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:gpui, _source, %GPUI.Runtime.Update{}} ->
        case evaluate(fun) do
          {:ok, value} when value not in [false, nil] -> value
          {:ok, _value} -> await_update(fun, deadline, last_error)
          {:error, error} -> await_update(fun, deadline, error)
        end
    after
      remaining ->
        flunk("update was not received before timeout; last error: #{inspect(last_error)}")
    end
  end

  defp nudge_frame!(native_window_id) do
    coordinate = Process.get(:gpui_frame_coordinate, 1)
    Process.put(:gpui_frame_coordinate, 3 - coordinate)
    request_frame!(native_window_id, coordinate, coordinate)
  end

  defp flush_updates(source) do
    receive do
      {:gpui, ^source, %GPUI.Runtime.Update{}} -> flush_updates(source)
    after
      0 -> :ok
    end
  end

  defp evaluate(fun) do
    {:ok, fun.()}
  rescue
    error in [ExUnit.AssertionError, MatchError] -> {:error, error}
  catch
    :exit, reason -> {:error, reason}
  end
end
